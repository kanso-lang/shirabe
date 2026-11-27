#!/bin/sh
# Prices everything in the Hetzner project at Hetzner's own rates and fails
# when the month would cost more than deploy/cost/budget, in euros with VAT.
# The cost workflow runs it every day with a read-only API token, so a
# failure arrives as GitHub's mail about a failed run.
#
#   HCLOUD_TOKEN=... sh deploy/cost/cost.sh
#
# Hetzner has no spending cap of its own, which is why this exists. It
# counts servers and their backups, traffic past what each server includes
# (projected from this month's so far), primary and floating IPs, volumes,
# load balancers, snapshots and backups. Object storage is not in the Cloud
# API, so a bucket is not counted.
#
# HCLOUD_ANSWERS names a directory of saved answers to read instead of the
# API, and TODAY a date, for deploy/cost/cost_test.sh.
set -eu
here=$(dirname "$0")
budget=$(cat "$here/budget")
today=${TODAY:-$(date -u +%Y-%m-%d)}
day=$(date -u -d "$today" +%-d)
days=$(date -u -d "$(date -u -d "$today" +%Y-%m-01) +1 month -1 day" +%-d)
answers=${HCLOUD_ANSWERS:-}
if [ -z "$answers" ]; then
  [ -n "${HCLOUD_TOKEN:-}" ] || { echo "cost: HCLOUD_TOKEN is not set"; exit 2; }
  answers=$(mktemp -d)
  trap 'rm -rf "$answers"' EXIT
  api=https://api.hetzner.cloud/v1
  for e in servers primary_ips floating_ips volumes load_balancers pricing; do
    curl -sf -H "Authorization: Bearer $HCLOUD_TOKEN" "$api/$e?per_page=50" \
      -o "$answers/$e.json" || { echo "cost: could not read $e"; exit 2; }
  done
  curl -sf -H "Authorization: Bearer $HCLOUD_TOKEN" \
    "$api/images?type=snapshot&type=backup&per_page=50" -o "$answers/images.json" ||
    { echo "cost: could not read images"; exit 2; }
fi
lines=$(jq -n -r --argjson day "$day" --argjson days "$days" \
  --slurpfile servers "$answers/servers.json" \
  --slurpfile primary_ips "$answers/primary_ips.json" \
  --slurpfile floating_ips "$answers/floating_ips.json" \
  --slurpfile volumes "$answers/volumes.json" \
  --slurpfile load_balancers "$answers/load_balancers.json" \
  --slurpfile images "$answers/images.json" \
  --slurpfile pricing "$answers/pricing.json" \
  -f "$here/cost.jq")
echo "$lines"
total=$(echo "$lines" | awk -F'\t' '$2 == "total" { print $1 }')
if awk -v t="$total" -v b="$budget" 'BEGIN { exit !(t > b) }'; then
  echo "cost: €$total a month is over the budget of €$budget"
  exit 1
fi
echo "cost: €$total a month, within the budget of €$budget"
