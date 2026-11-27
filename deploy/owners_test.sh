#!/bin/sh
# Rows made before owners existed go to the first account that confirmed its
# address, and a row that has an owner keeps it. Runs against the Postgres
# that PGHOST, PGPORT and PGUSER name, in a database of its own. Run from the
# repository's root:
#
#   sh deploy/owners_test.sh
set -eu
export PGDATABASE=shirabe_owners_test
dropdb --if-exists "$PGDATABASE" 2>/dev/null || true
createdb "$PGDATABASE"
trap 'dropdb --if-exists "$PGDATABASE"' EXIT
psql -v ON_ERROR_STOP=1 -q <<'SQL'
create table users (id serial, email text, confirmed text not null default '');
create table artists (id serial, owner text not null default '');
create table albums (id serial, owner text not null default '');
create table tracks (id serial, owner text not null default '');
insert into users (email, confirmed) values ('never@example.test', '');
insert into users (email, confirmed) values ('first@example.test', '2026');
insert into users (email, confirmed) values ('later@example.test', '2026');
insert into artists (owner) values (''), ('later@example.test');
insert into albums (owner) values ('');
insert into tracks (owner) values (''), ('');
SQL
SHIRABE_OWNERS_WAIT=2 sh deploy/owners.sh > /dev/null
got=$(psql -tAc "select string_agg(owner, ',' order by id) from (
  select id, owner from artists union all
  select 100 + id, owner from albums union all
  select 200 + id, owner from tracks) o")
want="first@example.test,later@example.test,first@example.test,first@example.test,first@example.test"
if [ "$got" != "$want" ]; then
  echo "FAIL: owners are $got"
  exit 1
fi
echo "ok: rows without owners go to the first confirmed account"
