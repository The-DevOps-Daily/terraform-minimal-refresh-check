#!/usr/bin/env bash
# Delete everything the lab created.
. "$(dirname "$0")/env.sh"
$TF destroy -input=false -auto-approve -var zone="$ZONE" -var records="$RECORDS" | tail -1
