# linux-admin-scripts

> Bash scripts for auditing and administering a Linux system — built to get
> hands-on practice with Linux administration rather than just reading about it.

	## Overview
	The first script, `user-audit.sh`, reports the security state of local user	
	accounts: whether each password is set, locked, or missing, and when it was
	last changed. It reads the same files an administrator would check by hand
	(`/etc/passwd`, `/etc/shadow`, `/etc/login.defs`) and summarises them in one
	place.

	## Environment
	Written and tested on Rocky Linux 9 (RHEL-family). Pure Bash with standard
	tools — awk, chage — so there is nothing to install. Passes ShellCheck with
	no warnings.

	## Usage
	```bash
	./user-audit.sh            # print report to stdout
	./user-audit.sh --help     # usage
	./user-audit.sh > audit.txt
	```

	Needs `sudo`: `/etc/shadow` is mode `----------`, so no ordinary user can
	read it. The script writes to stdout rather than a fixed file, so the caller
	decides where the output goes.

	## Example output
	=== polas ===
	password: set
	last change: never
	max age: 99999 days
	last login: Mon Sep 28 19:11:29 +0300 2026
	sudo: yes
	=== spiderman ===
	password: set
	last change: Jun 20, 2026
	max age: 99999 days
	last login: Sun Jul 5 17:20:03 +0300 2026
	sudo: no
	=== ironman ===
	password: set
	last change: Jun 19, 2026
	max age: 99999 days
	last login: never
	sudo: no
	=== nagios ===
	password: LOCKED
	last change: Jul 26, 2026
	max age: 99999 days
	last login: never
	sudo: no

	## What it checks
	- [x] Password status — set, locked, or never set
	- [x] Password aging — last change date and maximum age
	- [x] Last login - check user last-login activity
	- [x] Sudo rights - check user sudo access.

	## Planned
	- [ ] Group memberships
	- [ ] Accounts with UID 0 other than root
	- [ ] Shell assigned (`/sbin/nologin` vs an interactive shell)

	## Design notes
	- **UID range is read, not hardcoded.** The boundary between system and human
 	accounts comes from `UID_MIN` / `UID_MAX` in `/etc/login.defs`. A plain
 	`grep UID_MIN` also matches `SYS_UID_MIN` and `SUB_UID_MIN`, so the match is
	 anchored to the first field (`$1 == "UID_MIN"`) — otherwise the threshold
	 silently becomes 201 or 100000.
	- **Process substitution, not a pipe.** `mapfile -t users < <(awk ...)`. Piping
	into the loop would run it in a subshell, and the array would be empty once
	that subshell exited.
	- **`chage -l` runs once per user.** Its output is captured into a variable and
 	each field extracted from there, instead of calling the command once per
 	field.
	- **`lastlog`, not `last`.** Both report logins, but in different shapes.
	`lastlog` prints one line per account with its most recent login, which
	matches a loop that handles one user at a time. `last` prints an event
	history — every session and reboot, newest first — so getting one user's
	latest login means filtering the whole log and taking the first match.
	`last` also truncates usernames to eight characters (`spiderman` appears
	as `spiderma`), so matching on an exact username silently returns nothing.
	- **Testing for text, not counting fields.** When an account has never logged
	in, `lastlog` leaves the Port and From columns empty, so field positions
	shift between the two output shapes. The script checks whether the output
	contains "Never logged in" before trying to read a date, rather than
	relying on column positions that move.
	- **Asking `sudo`, not parsing sudoers.** Sudo rights come from several
 	places: the `wheel` group, explicit user lines in `/etc/sudoers`, and
 	drop-in files in `/etc/sudoers.d/` pulled in by the `#includedir` line —
 	which is active syntax, not a comment, despite the leading `#`. Rather
 	than parse all of them and risk getting the precedence wrong, the script
 	calls `sudo -l -U "$user"` and lets sudo resolve its own rules.

	## Notable problem solved: locked is not the same as no password
	Both a locked account and a service account look unusable, but they are
	different states in `/etc/shadow`. I locked a test account with `passwd -l`
	and compared field 2 before and after: the hash was unchanged, with `!!`
	prefixed to it. Nothing can hash to a value starting with `!`, so every login
	attempt fails — but the original password is still there and `passwd -u`
	restores it. A service account instead has `*` and never had a password at
	all, so there is nothing to unlock. The script reports these separately
	because an auditor needs to know which one they are looking at.

	## Caveats
	- The UID range is a heuristic, not a guarantee. On this system `nagios` was
	created above `UID_MIN`, so a service account appears in the report
	alongside real users.
	- A locked password does not mean the account is unusable. SSH key
	authentication never touches `/etc/shadow`, so a locked account with an
	authorized key can still log in.
	- `lastlog` reads `/var/log/lastlog`, which is only updated by login paths
	configured to write it through PAM. "Never logged in" therefore means "no
	recorded login", not "definitely never accessed". `last` reads a different
	file (`/var/log/wtmp`) and can show sessions that `lastlog` missed.
	- The sudo check reports yes or no, not scope. An account allowed to run
 	a single command shows the same as one with `(ALL) ALL`, so a "yes" here
 	means "has some sudo rights", not "has full root".

	## What I learned
	- `awk` matches fields, `grep` matches lines — anchoring to `$1` avoids
	matching the wrong configuration key.
	- The three password states in `/etc/shadow` and why they are not
	interchangeable.
	- `set -euo pipefail`: fail loudly instead of producing a wrong report.
	- Git has three states — working tree, staged, committed — and `git add`
	alone pushes nothing.
	- ShellCheck catches unquoted variables and other common Bash mistakes.
	- `lastlog` and `last` read different files and answer different questions:
	one gives the latest login per account, the other a full event history.
	- `$(...)` captures a command's output; `<<<` feeds a string into a command's
	input. Using one where the other belongs is a silent failure.
	- `if` in Bash branches on a command's exit status, not on an expression —
	which is why `grep -q` works as a test condition.
	- `sed 's/^ *//'` strips leading whitespace; `^` and `$` are the same anchors
	regex uses everywhere.
	- PAM is what decides whether a login gets recorded at all, so an audit tool
	is only as complete as the logging underneath it.
	- Sudo rights have several sources, and group membership alone does not
	answer the question.
	- `/etc/sudoers` is edited with `visudo`, which validates the syntax before
	saving — a broken sudoers file can lock everyone out of admin access.
	- Checking a command's exit status (`$?`) before relying on it matters under
	`set -e`: a "no" answer is not necessarily a failure.
