#!/usr/bin/env bash
# Change three records behind Terraform's back, then see which plans notice:
#   r[42]    deleted
#   r[43]    TTL 1800 -> 60
#   pointer  TTL 1800 -> 60 (it depends on r[0])
. "$(dirname "$0")/env.sh"
out="$RESULTS/drift-$(date -u +%Y%m%dT%H%M%SZ).tsv"
echo "# drift.sh $(stamp) started=$(date -u +%FT%TZ)" > "$out"
id() { $TF state show -no-color "$1" | awk '$1 == "id" { gsub(/"/, "", $3); print $3 }'; }
r42=$(id 'digitalocean_record.r[42]') r43=$(id 'digitalocean_record.r[43]') ptr=$(id 'digitalocean_record.pointer')
api="https://api.digitalocean.com/v2/domains/$ZONE/records"
echo "# out of band: DELETE r[42] -> $(do_api -o /dev/null -w '%{http_code}' -X DELETE "$api/$r42"), PATCH r[43] ttl=60 -> $(do_api -o /dev/null -w '%{http_code}' -X PATCH "$api/$r43" -d '{"ttl":60}'), PATCH pointer ttl=60 -> $(do_api -o /dev/null -w '%{http_code}' -X PATCH "$api/$ptr" -d '{"ttl":60}')" >> "$out"
printf 'label\tseconds\tgets\trequests\tchanges\n' >> "$out"
p="$(dirname "$0")/plan.sh"
"$p" full/no-change >> "$out"
"$p" minimal/no-change -minimal-refresh >> "$out"
"$p" full/r0-changed -var changed=0 >> "$out"
"$p" minimal/r0-changed -var changed=0 -minimal-refresh >> "$out"
"$p" refresh-only -refresh-only >> "$out"
"$p" destroy/full -destroy >> "$out"
"$p" destroy/minimal -destroy -minimal-refresh >> "$out"
echo "# ended=$(date -u +%FT%TZ)" >> "$out"
echo "$out"; python3 - "$out" <<'PY'
import sys
for line in open(sys.argv[1]):
    if line.startswith("#") or line.startswith("label"): print(line.rstrip()[:220]); continue
    l, s, g, t, ch = line.rstrip("\n").split("\t")
    acts = [c for c in ch.split(",") if c != "none"]
    shown = [c for c in acts if "r[" not in c or any(k in c for k in ("r[0]", "r[42]", "r[43]"))]
    print(f"{l:18} {s:>6}s {g:>4} GET  {len(acts):>3} changes  {', '.join(shown)[:150]}")
PY
