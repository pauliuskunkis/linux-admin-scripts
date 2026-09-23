#!/usr/bin/env bash
#
# user-audit.sh - audit local user accounts.
# Currently reports password status (locked / none / set).
# Planned: sudo rights, last login, password aging.

# -e  exit immediately if any command fails
# -u  treat use of an unset variable as an error
# -o pipefail  a pipeline fails if ANY stage fails, not just the last
set -euo pipefail

usage() {
    # Heredoc: everything until the EOF marker is printed as-is.
    cat <<EOF
Usage: ${0##*/}

Audits local user accounts and writes a report to stdout.
Redirect to save: ${0##*/} > audit.txt

Options:
  -h, --help    Show this help and exit
EOF
}

# ${1:-} means "$1, or empty if unset" - without the :- the script
# would abort under set -u when run with no arguments at all.
case "${1:-}" in
    -h|--help) usage; exit 0 ;;
esac

# Read the UID range from the system instead of hardcoding 1000.
# $1 == "UID_MIN" is an exact match on the first word: a plain grep
# would also hit SYS_UID_MIN and SUB_UID_MIN and give a wrong number.
uid_min=$(awk '$1 == "UID_MIN" { print $2 }' /etc/login.defs)
uid_max=$(awk '$1 == "UID_MAX" { print $2 }' /etc/login.defs)

# Build the list of human accounts. Field 3 of /etc/passwd is the UID;
# the lower bound skips system accounts, the upper bound skips nobody
# (65534). mapfile reads each line into an array element (-t strips the
# newline). < <(...) is process substitution - a pipe would run the
# loop in a subshell and the array would be empty afterwards.
mapfile -t users < <(awk -F: -v min="$uid_min" -v max="$uid_max" \
    '$3 >= min && $3 <= max { print $1 }' /etc/passwd)

for user in "${users[@]}"; do
    echo "=== $user ==="

    # Password status. Field 2 of /etc/shadow holds the hash; the file
    # is mode 000 so this needs sudo. Match on $1 == u rather than grep
    # so "rpc" does not also match "rpcuser".
    pw_field=$(sudo awk -F: -v u="$user" '$1 == u { print $2 }' /etc/shadow)

    # ! prefix: account is locked - the hash is still there but nothing
    #   can ever match it. Reversible with passwd -u.
    # * or empty: no password was ever set. Not the same as locked -
    #   there is nothing to unlock.
    case "$pw_field" in
        \!*)   echo "  password: LOCKED"   ;;
        \*|"") echo "  password: none set" ;;
        *)     echo "  password: set"      ;;
    esac

    # chage -l gives aging data as readable date, run it once and
    # extract fields from the captured output rather than calling it
    # again per field.
    aging=$(sudo chage -l "$user")

    # -F' *: *' makes the separator "spaces, colon, spaces" so the
    # value comes out without the padding chage uses to align columns.
    last_change=$(awk -F' *: *' '/Last password change/ { print $2 }' <<< "$aging")
    max_days=$(awk -F' *: *' '/Maximum/ { print $2 }' <<< "$aging")

    echo "  last change: $last_change"
    echo "  max age: $max_days days"
done
