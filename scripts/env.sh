# Shared settings, sourced by every script. Run the scripts from the repo root.
set -euo pipefail
TF=${TF:-terraform}
: "${ZONE:?set ZONE to a zone name under a domain you control, for example tf-lab.yourdomain.com}"
RECORDS=${RECORDS:-200}
RESULTS=${RESULTS:-results}
mkdir -p "$RESULTS"
: "${DIGITALOCEAN_TOKEN:?set DIGITALOCEAN_TOKEN (needs domain read, create and delete)}"
export DIGITALOCEAN_TOKEN
stamp() { echo "sha256=$(cat main.tf scripts/*.sh | sha256sum | cut -c1-12) $($TF version | head -1) zone=$ZONE records=$RECORDS"; }
do_api() { curl -sS -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" -H "Content-Type: application/json" "$@"; }
