#!/usr/bin/env bash
# Why did back-to-back full plans take 60 s with no retries and no 429s?
# Two full plans in a row with the provider log kept, then per run: response
# status counts, the slowest requests and the rate-limit headers. Only these
# derived fields are written; the raw log (it holds request headers) is deleted.
. "$(dirname "$0")/env.sh"
out="$RESULTS/burst-log-$(date -u +%Y%m%dT%H%M%SZ).txt"
echo "# burst-log.sh $(stamp) started=$(date -u +%FT%TZ)" > "$out"
sleep "${COOL:-65}"
for run in 1 2; do
  log=$(mktemp)
  KEEP_LOG=$log "$(dirname "$0")/plan.sh" "burst/full/$run" >> "$out"
  python3 - "$log" >> "$out" <<'PY'
import re, sys, datetime as dt, collections
ts = lambda l: dt.datetime.strptime(l.split()[0], "%Y-%m-%dT%H:%M:%S.%f%z")
req, rows, status, limits = None, [], collections.Counter(), []
lines = open(sys.argv[1], errors="replace").read().splitlines()
for i, l in enumerate(lines):
    if "API Request Details" in l:
        path = next((x for x in lines[i:i + 6] if re.match(r"^(GET|POST|PUT|PATCH|DELETE) /v2/", x)), "?")
        req = (ts(l), path.split()[1] if " " in path else path)
    elif "API Response Details" in l and req:
        st = next((x for x in lines[i:i + 6] if x.startswith("HTTP/")), "?")
        status[st.split(" ", 1)[1] if " " in st else st] += 1
        rows.append(((ts(l) - req[0]).total_seconds(), req[1].rsplit("/", 1)[-1], st))
        for x in lines[i:i + 40]:
            m = re.match(r"(?i)^ratelimit-(remaining|reset):\s*(\d+)", x)
            if m: limits.append((m.group(1).lower(), int(m.group(2))))
            if x.startswith("-----") and "RESPONSE" not in x: break
        req = None
lat = sorted(rows, reverse=True)
print(f"  responses: {dict(status)}; latency median {sorted(r[0] for r in rows)[len(rows)//2]:.2f} s, max {lat[0][0]:.2f} s, requests over 5 s: {sum(r[0] > 5 for r in rows)}")
print("  slowest: " + "; ".join(f"{r[0]:.1f}s {r[2]}" for r in lat[:5]))
rem = [v for k, v in limits if k == "remaining"]
print(f"  ratelimit-remaining seen: first {rem[:1]}, last {rem[-1:]}, min {min(rem) if rem else None}")
PY
  rm -f "$log"
done
echo "# ended=$(date -u +%FT%TZ)" >> "$out"
cat "$out"
