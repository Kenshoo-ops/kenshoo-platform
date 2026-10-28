#!/usr/bin/env bash
# Retries "terraform apply" while OCI reports no ARM capacity. Stops on any other error.
set -euo pipefail

# Private temp file (mode 600), removed on every exit path.
LOG=$(mktemp "${TMPDIR:-/tmp}/kenshoo-apply.XXXXXX")
trap 'rm -f "$LOG"' EXIT

for i in $(seq 1 72); do
  echo "Attempt $i"
  if terraform apply -auto-approve -var create_instance=true 2>&1 | tee "$LOG"; then
    echo "Done."
    exit 0
  fi
  if ! grep -qi "out of host capacity" "$LOG"; then
    echo "Failed for a reason other than capacity. Stopping."
    exit 1
  fi
  echo "No capacity yet, retrying in 5 minutes."
  sleep 300
done
echo "Gave up after 72 attempts (about 6 hours)."
exit 1
