#!/usr/bin/env bash
# One measured plan. Usage: plan.sh <label> [extra terraform plan args...]
# Runs the plan twice: once timed with no logging, then once with TF_LOG=DEBUG
# to count the provider's API requests (logging slows the plan down, so it is
# kept out of the timing). Prints label, seconds, GET requests, all requests,
# and the address and actions of every resource the plan would change.
. "$(dirname "$0")/env.sh"
label=$1; shift
log=$(mktemp) plan=$(mktemp)
args=(-input=false -lock=false -var zone="$ZONE" -var records="$RECORDS" "$@")
start=$(date +%s.%N)
$TF plan "${args[@]}" -out="$plan" >/dev/null
end=$(date +%s.%N)
TF_LOG=DEBUG TF_LOG_PATH=$log $TF plan "${args[@]}" >/dev/null
gets=$(grep -cE '^GET /v2/' "$log" || true)
total=$(grep -cE '^(GET|POST|PUT|PATCH|DELETE) /v2/' "$log" || true)
changes=$($TF show -json "$plan" | python3 -c '
import json, sys
p = json.load(sys.stdin)
print(",".join(r["address"] + ":" + "/".join(r["change"]["actions"]) for r in p.get("resource_changes", []) if r["change"]["actions"] != ["no-op"]) or "none")')
printf '%s\t%.1f\t%s\t%s\t%s\n' "$label" "$(echo "$end - $start" | bc)" "$gets" "$total" "$changes"
rm -f "$log" "$plan"
