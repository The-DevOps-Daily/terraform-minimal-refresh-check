#!/usr/bin/env bash
# Plan time and API requests: full refresh vs -minimal-refresh vs -refresh=false,
# with no config change and with one record changed in config.
. "$(dirname "$0")/env.sh"
out="$RESULTS/bench-$(date -u +%Y%m%dT%H%M%SZ).tsv"
echo "# bench.sh $(stamp) started=$(date -u +%FT%TZ)" > "$out"
printf 'label\tseconds\tgets\trequests\tchanges\n' >> "$out"
for run in 1 2; do
  for mode in full minimal norefresh; do
    case $mode in full) flag=() ;; minimal) flag=(-minimal-refresh) ;; norefresh) flag=(-refresh=false) ;; esac
    "$(dirname "$0")/plan.sh" "$mode/no-change/$run" "${flag[@]}" >> "$out"
    "$(dirname "$0")/plan.sh" "$mode/one-change/$run" -var changed=7 "${flag[@]}" >> "$out"
  done
done
echo "# ended=$(date -u +%FT%TZ)" >> "$out"
echo "$out"; column -t -s $'\t' "$out" | cut -c1-160
