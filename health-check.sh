#!/usr/bin/env bash
#
# health-check.sh - report basic system health.
# Currently reports disk usage.
# Planned: failed services, memory, load, uptime.

# -e  exit immediately if any command fails
# -u  treat use of an unset variable as an error
# -o pipefail  a pipeline fails if ANY stage fails, not just the last
set -euo pipefail

usage() {
    # Heredoc: everything until the EOF marker is printed as-is.
    cat <<EOF
Usage: ${0##*/}

Reports basic system health to stdout.
Redirect to save: ${0##*/} > health.txt

Options:
  -h, --help    Show this help and exit
EOF
}

# ${1:-} means "$1, or empty if unset" - without the :- the script
# would abort under set -u when run with no arguments at all.
case "${1:-}" in
    -h|--help) usage; exit 0 ;;
esac

# -x excludes a filesystem type. tmpfs and devtmpfs live in RAM, so
# they are noise in a disk report.
echo "=== Disk usage ==="
df -h -x tmpfs -x devtmpfs

# --failed lists units that tried to start and errored. A healthy system
# prints nothing.
echo
echo "=== Failed services ==="
systemctl --failed --no-pager

# -h gives human-readable units. The "available" column matters more than
# "free" - Linux uses spare RAM for cache and frees it on demand.
echo
echo "=== Memory ==="
free -h

# Load average is the 1/5/15-minute run queue length. Compare it against
# core count: a load of 4 is fine on 4 cores, not on 1.
echo
echo "=== Uptime and load ==="
uptime
