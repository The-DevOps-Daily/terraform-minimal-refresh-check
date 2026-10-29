# Sources

Excerpts behind the claims in the README and the write-up that the lab does not measure itself. Retrieved 2026-10-29.

## Terraform

[v1.17.0 release notes](https://github.com/hashicorp/terraform/releases/tag/v1.17.0), published 2026-10-21T17:32:54Z:

> A new `-minimal-refresh` planning option has been added, which will only refresh resources that have proposed changes. (#35290)

[`terraform plan` docs](https://developer.hashicorp.com/terraform/cli/commands/plan):

> Reduces the number of remote API requests by refreshing only resource instances that Terraform plans to change.

> this option causes Terraform to ignore external changes to resources that have no planned changes

> Each resource instance independently determines whether it needs to be refreshed

> You cannot use `-minimal-refresh` in refresh-only planning mode, or in combination with the `-refresh=false` option.

> Avoid using `-minimal-refresh` or `-refresh=false` when upgrading provider versions

[PR #38953](https://github.com/hashicorp/terraform/pull/38953), "plan: Introduce `-minimal-refresh` flag to only refresh resources that have proposed changes", merged 2026-08-19:

> Each resource instance chooses whether it will refresh in isolation based on it's own plan, so a refresh on one resource will not cause other resources that depend on it to refresh.

> this solution uses an initial plan call as the indicator of whether we need to perform the refresh for a particular resource instance. If a change is produced for a resource using this flag, we discard that initial plan, do a refresh, and plan again.

> Destroy plans + deposed/orphaned resources will not refresh using this flag.

## DigitalOcean API

[API description, "Rate Limit"](https://github.com/digitalocean/openapi/blob/main/specification/description.yml):

> Requests through the API are rate limited per OAuth token. Current rate limits:
> * 5,000 requests per hour
> * 250 requests per minute (5% of the hourly total)

> **retry-after**: The number of seconds to wait before making another request when rate limited.

## DigitalOcean Terraform provider, v2.106.0

[digitalocean/config/config.go](https://github.com/digitalocean/terraform-provider-digitalocean/blob/v2.106.0/digitalocean/config/config.go), lines 81-106: when `http_retry_max` is above 0 the godo client is built with `godo.WithRetryAndBackoffs(retryConfig)`, and afterwards the request logger wraps that client's transport:

```go
clientTransport := logging.NewTransport("DigitalOcean", godoClient.HTTPClient.Transport)
godoClient.HTTPClient.Transport = clientTransport
```

[digitalocean/provider.go](https://github.com/digitalocean/terraform-provider-digitalocean/blob/v2.106.0/digitalocean/provider.go): defaults `http_retry_max` 4, `http_retry_wait_min` 1.0, `http_retry_wait_max` 30.0, `requests_per_second` 0.0.

[digitalocean/domain/resource_record.go](https://github.com/digitalocean/terraform-provider-digitalocean/blob/v2.106.0/digitalocean/domain/resource_record.go), `resourceDigitalOceanRecordDelete`:

```go
resp, delErr := client.Domains.DeleteRecord(context.Background(), domain, id)
if delErr != nil {
	// If the record is somehow already destroyed, mark as
	// successfully gone
	if resp != nil && resp.StatusCode == 404 {
		return nil
	}
	return diag.Errorf("Error deleting record: %s", delErr)
}
```
