#!/usr/bin/env bash
# Create the zone and the records.
. "$(dirname "$0")/env.sh"
$TF init -input=false -upgrade >/dev/null
$TF apply -input=false -auto-approve -var zone="$ZONE" -var records="$RECORDS" | tail -3
