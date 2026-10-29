terraform {
  required_version = ">= 1.17.0"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.106.0"
    }
  }
}

# The token comes from DIGITALOCEAN_TOKEN. The zone is never delegated, so the
# records exist only in DigitalOcean's API and serve no real DNS traffic.
variable "zone" {
  type = string
}

variable "records" {
  type    = number
  default = 200
}

# Index of one record whose value changes in config (-1 = no config change).
variable "changed" {
  type    = number
  default = -1
}

resource "digitalocean_domain" "lab" {
  name = var.zone
}

resource "digitalocean_record" "r" {
  count  = var.records
  domain = digitalocean_domain.lab.id
  type   = "TXT"
  name   = format("r%03d", count.index)
  value  = count.index == var.changed ? "v2" : "v1"
  ttl    = 1800
}

# Depends on r[0], so a config change to r[0] touches it in the graph.
resource "digitalocean_record" "pointer" {
  domain = digitalocean_domain.lab.id
  type   = "CNAME"
  name   = "pointer"
  value  = "${digitalocean_record.r[0].fqdn}."
  ttl    = 1800
}
