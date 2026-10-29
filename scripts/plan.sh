#!/usr/bin/env bash
# One measured plan. Usage: plan.sh <label> [extra terraform plan args...]
# Logs at TF_LOG=DEBUG (the provider prints each API request only then) and
# prints: label, seconds, GET requests, all requests, 429 responses, and the
# address and actions of every resource the plan would change, then the drift
# Terraform detected while refreshing (resource_drift). Every mode pays
# the same logging cost; bench2.sh measures that cost once.
. "$(dirname "$0")/env.sh"
label=$1; shift
log=$(mktemp) plan=$(mktemp)
start=$(date +%s.%N)
TF_LOG=${PLAN_LOG:-DEBUG} TF_LOG_PATH=$log $TF plan -input=false -lock=false -var zone="$ZONE" -var records="$RECORDS" -out="$plan" "$@" >/dev/null
end=$(date +%s.%N)
gets=$(grep -cE '^GET /v2/' "$log" || true)
total=$(grep -cE '^(GET|POST|PUT|PATCH|DELETE) /v2/' "$log" || true)
limited=$(grep -cE '^HTTP/[0-9.]+ 429' "$log" || true)
changes=$($TF show -json "$plan" | python3 -c '
import json, sys
p = json.load(sys.stdin)
fmt = lambda rs: ",".join(r["address"] + ":" + "/".join(r["change"]["actions"]) for r in rs if r["change"]["actions"] != ["no-op"]) or "none"
print(fmt(p.get("resource_changes", [])) + "\t" + fmt(p.get("resource_drift", [])))')
printf '%s\t%.1f\t%s\t%s\t%s\t%s\n' "$label" "$(echo "$end - $start" | bc)" "$gets" "$total" "$limited" "$changes"
[ -n "${KEEP_LOG:-}" ] && cp "$log" "$KEEP_LOG"
rm -f "$log" "$plan"
