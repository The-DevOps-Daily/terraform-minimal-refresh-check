# terraform-minimal-refresh-check

Measure what Terraform 1.17's `-minimal-refresh` plan option saves, and what it stops seeing, against a real API: 200 DNS records on DigitalOcean (free, no droplets).

```bash
export DIGITALOCEAN_TOKEN=...   # needs domain read, create and delete
export ZONE=tf-lab.yourdomain.com  # a zone name under a domain you control; it is never delegated
scripts/setup.sh      # create the zone, 200 TXT records and one CNAME (202 resources)
scripts/bench2.sh     # plan time, API requests and 429s: full refresh vs -minimal-refresh vs -refresh=false
scripts/drift.sh      # change three records behind Terraform's back, then see which plans notice
scripts/teardown.sh   # delete everything
```

Requires Terraform 1.17.0 or later (`TF=/path/to/terraform` to pick a binary) and about 3,000 of DigitalOcean's 5,000 API requests per hour for one full pass. Write-up: [Terraform 1.17's -minimal-refresh, measured](https://devops-daily.com/posts/terraform-1-17-minimal-refresh-measured).

## What each script does

- `setup.sh` applies `main.tf`: one zone, `RECORDS` (default 200) TXT records `r000`..`r199`, and a CNAME `pointer` whose value depends on `r[0]`.
- `plan.sh <label> [args]` runs one `terraform plan` with `TF_LOG=DEBUG` (the provider prints each API request only at that level) and prints the time, the GET count, all requests, the number of `429 Too Many Requests` responses, and every resource the plan would change.
- `bench.sh` was the first benchmark. It ran each plan twice back to back, which pushed full plans past DigitalOcean's 250 requests per minute; its request counts are valid, its timings are not (see the note in its result file).
- `bench2.sh` waits 65 seconds before every full plan and then runs three full plans back to back to show the rate limit on purpose. (Its logging-cost step was broken: unsetting `TF_LOG` still logged.)
- `burst-log.sh` runs two full plans back to back with the log kept and reports response statuses, the slowest requests and the rate-limit headers, without saving the raw log.
- `drift.sh` deletes `r[42]`, sets the TTL of `r[43]` and of `pointer` to 60 through the API, then plans with and without `-minimal-refresh`, with a config change on `r[0]`, in refresh-only mode, and as destroy plans.
- `teardown.sh` deletes everything; `MINIMAL=1` does it with `apply -destroy -minimal-refresh` and records the result.

Every result file starts with a line that names the script hash, the Terraform version, the zone and the record count. Predictions were committed before each run (`results/predictions-*.txt`).

## Results

Terraform 1.17.0, provider digitalocean 2.106.0, a Raspberry Pi 3 B+ (1 GB RAM), 2026-10-29.

| Plan | GET requests | Median time | What it would change |
| --- | --- | --- | --- |
| Full refresh, no change | 202 | 9.5 s | nothing |
| `-minimal-refresh`, no change | 0 | 4.3 s | nothing |
| `-minimal-refresh`, one record changed in config | 1 | 4.5 s | that record |
| `-refresh=false` | 0 | 4.5 s | nothing |
| 2nd and 3rd full plan within a minute | 202 each | 60.4 s, 60.6 s | nothing |

`bench2-20261029T114834Z.tsv`, three runs each. In the slow back-to-back plans one request waited 50.1 s (`burst-log-20261029T120706Z.txt`): DigitalOcean allows 250 requests per minute, and the provider logs around its retry client, so the 429 and the wait do not show up as separate requests in `TF_LOG`.

After deleting `r[42]` and setting the TTL of `r[43]` and `pointer` to 60 out of band (`drift-20261029T124036Z.tsv`):

| Plan | Changes it shows |
| --- | --- |
| Full refresh | `pointer`, `r[42]`, `r[43]` (3) |
| `-minimal-refresh` | none |
| Full refresh, `r[0]` changed in config | `r[0]` plus the 3 drifted resources |
| `-minimal-refresh`, `r[0]` changed in config | `r[0]` only: `pointer` depends on `r[0]` but is not refreshed |
| `-refresh-only` | drift on all 3 |
| Destroy, full refresh | 201 deletes |
| Destroy, `-minimal-refresh` | 202 deletes, including `r[42]`, which no longer existed |

`apply -destroy -minimal-refresh` then succeeded with "202 destroyed" (`teardown-20261029T124712Z.txt`): the DigitalOcean provider treats a 404 on delete as already deleted. A provider that does not would fail there.

The first benchmark (`bench-20261029T113954Z.tsv`) and the first drift run (`drift-20261029T115919Z.tsv`) are kept with a note on their second line explaining what was wrong with them. The whole lab used about 6,300 API requests.
