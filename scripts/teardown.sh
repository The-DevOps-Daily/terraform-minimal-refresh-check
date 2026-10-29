#!/usr/bin/env bash
# Delete everything the lab created. MINIMAL=1 destroys with -minimal-refresh,
# which skips the refresh, so resources deleted out of band are still in the
# plan; the result is recorded in results/teardown-*.txt.
. "$(dirname "$0")/env.sh"
if [ -n "${MINIMAL:-}" ]; then
  out="$RESULTS/teardown-$(date -u +%Y%m%dT%H%M%SZ).txt"
  echo "# teardown.sh MINIMAL=1 $(stamp)" > "$out"
  set +e
  $TF apply -destroy -minimal-refresh -input=false -auto-approve -no-color -var zone="$ZONE" -var records="$RECORDS" > "$out.log" 2>&1
  echo "exit=$?" >> "$out"
  set -e
  grep -E "Error|Destroy complete|destroyed" "$out.log" | tail -5 >> "$out"
  rm -f "$out.log"
  cat "$out"
else
  $TF destroy -input=false -auto-approve -var zone="$ZONE" -var records="$RECORDS" | tail -1
fi
