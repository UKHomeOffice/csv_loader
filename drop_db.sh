#!/usr/bin/env bash


cat <<EOF >>/tmp/clean.sql
\c $DB_NAME
drop database ref;
drop user anonuser,authuser,dbowner,readonlyuser,serviceuser;
drop table flyway_schema_history;
\q
EOF

docker exec -i db psql -U postgres < /tmp/clean.sql

rm /tmp/clean.sql
