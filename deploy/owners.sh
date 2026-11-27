#!/bin/sh
# Run as root once the app has started, by `ExecStartPost=+` in
# shirabe.service, with the app's database settings from /etc/shirabe/env.
# Artists, albums and tracks made before they had owners belong to the
# first account that confirmed its address, which is the one that made
# them. The app adds the `owner` columns as it starts, so this waits for
# them. A row that has an owner is left alone, so once every row has one
# this changes nothing.
set -eu
asked() {
  psql -tAc "select 1 from information_schema.columns
    where table_name = 'tracks' and column_name = 'owner'"
}
tries=0
until [ "$(asked)" = 1 ]; do
  tries=$((tries + 1))
  if [ "$tries" -ge "${SHIRABE_OWNERS_WAIT:-60}" ]; then
    echo "shirabe owners: the owner columns are not there yet"
    exit 0
  fi
  sleep 1
done
psql -v ON_ERROR_STOP=1 -q <<'SQL'
with first as (
  select email from users where confirmed <> '' order by id limit 1
)
update artists set owner = first.email from first where artists.owner = '';
with first as (
  select email from users where confirmed <> '' order by id limit 1
)
update albums set owner = first.email from first where albums.owner = '';
with first as (
  select email from users where confirmed <> '' order by id limit 1
)
update tracks set owner = first.email from first where tracks.owner = '';
SQL
echo "shirabe owners: every row has an owner"
