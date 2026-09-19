#!/usr/bin/env bash
# user-audit.sh - reports on local user accounts: sudo rights,
# last login, locked/inactive accounts, password aging.

set -euo pipefail

usage() {
    cat <<EOF
Usage: ${0##*/}

Audits local user accounts and writes a report to stdout.
Redirect to save: ${0##*/} > audit.txt

Options:
  -h, --help    Show this help and exit
EOF
}

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
esac

# Thresholds come from the system, not hardcoded, so this works
# on any distro where the admin changed the defaults.
uid_min=$(awk '$1 == "UID_MIN" { print $2 }' /etc/login.defs)
uid_max=$(awk '$1 == "UID_MAX" { print $2 }' /etc/login.defs)

# Human accounts only: UID inside [uid_min, uid_max] excludes both
# system accounts (low UIDs) and nobody (65534, above UID_MAX).
mapfile -t users < <(awk -F: -v min="$uid_min" -v max="$uid_max" \
    '$3 >= min && $3 <= max { print $1 }' /etc/passwd)

for user in "${users[@]}"; do
    echo "=== $user ==="
    # audit sections go here
done
