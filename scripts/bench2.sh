#!/usr/bin/env bash
# Clean timings. bench.sh mixed DigitalOcean's 250 requests/minute limit into
# the full-refresh times, so here every full plan waits a minute first, the
# logging cost is measured once, and the rate-limit effect is measured on
# purpose with three full plans back to back.
. "$(dirname "$0")/env.sh"
out="$RESULTS/bench2-$(date -u +%Y%m%dT%H%M%SZ).tsv"
echo "# bench2.sh $(stamp) started=$(date -u +%FT%TZ)" > "$out"
printf 'label\tseconds\tgets\trequests\t429s\tchanges\n' >> "$out"
p="$(dirname "$0")/plan.sh"
cool() { sleep "${COOL:-65}"; }
for run in 1 2 3; do
  cool; "$p" "quiet/full/no-change/$run" >> "$out"
  "$p" "quiet/minimal/no-change/$run" -minimal-refresh >> "$out"
  "$p" "quiet/minimal/one-change/$run" -var changed=7 -minimal-refresh >> "$out"
  "$p" "quiet/norefresh/no-change/$run" -refresh=false >> "$out"
done
cool; PLAN_LOG= "$p" "logcost/full/no-log" >> "$out"
cool; "$p" "logcost/full/log" >> "$out"
cool; for run in 1 2 3; do "$p" "burst/full/no-change/$run" >> "$out"; done
echo "# ended=$(date -u +%FT%TZ)" >> "$out"
echo "$out"; column -t -s $'\t' "$out" | cut -c1-120
