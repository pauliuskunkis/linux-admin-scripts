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
	=== nagios ===
	password: LOCKED
	last change: Jul 26, 2026
	max age: 99999 days


	## What it checks
	- [x] Password status — set, locked, or never set
	- [x] Password aging — last change date and maximum age
	- [ ] Last login
	- [ ] Sudo rights

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

## What I learned
- `awk` matches fields, `grep` matches lines — anchoring to `$1` avoids
  matching the wrong configuration key.
- The three password states in `/etc/shadow` and why they are not
  interchangeable.
- `set -euo pipefail`: fail loudly instead of producing a wrong report.
- Git has three states — working tree, staged, committed — and `git add`
  alone pushes nothing.
- ShellCheck catches unquoted variables and other common Bash mistakes.
