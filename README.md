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

Requires Terraform 1.17.0 or later (`TF=/path/to/terraform` to pick a binary) and about 2,500 API requests of DigitalOcean's 5,000 per hour. Write-up: [link updated when the post is live].

## What each script does

- `setup.sh` applies `main.tf`: one zone, `RECORDS` (default 200) TXT records `r000`..`r199`, and a CNAME `pointer` whose value depends on `r[0]`.
- `plan.sh <label> [args]` runs one `terraform plan` with `TF_LOG=DEBUG` (the provider prints each API request only at that level) and prints the time, the GET count, all requests, the number of `429 Too Many Requests` responses, and every resource the plan would change.
- `bench.sh` was the first benchmark. It ran each plan twice back to back, which pushed full plans past DigitalOcean's 250 requests per minute; its request counts are valid, its timings are not (see the note in its result file).
- `bench2.sh` waits 65 seconds before every full plan, measures the logging cost once, and then runs three full plans back to back to show the rate limit on purpose.
- `drift.sh` deletes `r[42]`, sets the TTL of `r[43]` and of `pointer` to 60 through the API, then plans with and without `-minimal-refresh`, with a config change on `r[0]`, in refresh-only mode, and as destroy plans.

Every result file starts with a line that names the script hash, the Terraform version, the zone and the record count. Predictions were committed before each run (`results/predictions-*.txt`).

## Results

[[RESULTS]]
