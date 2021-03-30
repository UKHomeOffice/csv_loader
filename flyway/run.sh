#!/usr/bin/env bash

# Ensure environment values are not exposed in drone output
set +x

echo "Exporting environment variables"


export FLYWAY_USER="${FLYWAY_USER:=postgres}"
export FLYWAY_PASSWORD="${FLYWAY_PASSWORD:=password}"
export DB_HOSTNAME="${DB_HOSTNAME:=postgres}"
export DB_PORT="${DB_PORT:=5432}"
export DB_DEFAULT_NAME="${DB_DEFAULT_NAME:=postgres}"
export DB_OPTIONS="${DB_OPTIONS:=}"
export DB_JDBC_OPTIONS="${DB_JDBC_OPTIONS:=}"

export URL="postgresql://${FLYWAY_USER}:${FLYWAY_PASSWORD}@${DB_HOSTNAME}:${DB_PORT}/${DB_DEFAULT_NAME}${DB_OPTIONS}"
export FLYWAY_URL="jdbc:postgresql://${DB_HOSTNAME}:${DB_PORT}/${DB_DEFAULT_NAME}${DB_JDBC_OPTIONS}"

export FLYWAY_PLACEHOLDERS_MASTERUSER="${FLYWAY_USER:=postgres}"
export FLYWAY_PLACEHOLDERS_REFERENCEDBNAME="${DB_NAME:=ref}"
export FLYWAY_PLACEHOLDERS_REFERENCEOWNERNAME="${DB_OWNERNAME:=dbowner}"
export FLYWAY_PLACEHOLDERS_REFERENCEOWNERPASSWORD="${DB_OWNERPASSWORD:=dboPwd}"
export FLYWAY_PLACEHOLDERS_REFERENCESCHEMA="${DB_SCHEMA:=public}"
export FLYWAY_LOCATIONS_INIT="${FLYWAY_LOCATIONS_INIT:=filesystem:/flyway/schemas/init}"
export FLYWAY_INIT_CONF="${FLYWAY_INIT_CONF:=/flyway/conf/init.conf}"
export FLYWAY_LOCATIONS_REFERENCE="${FLYWAY_LOCATIONS_REFERENCE:=filesystem:/flyway/schemas/reference}"
export FLYWAY_REFERENCE_CONF="${FLYWAY_REFERENCE_CONF:=/flyway/conf/reference.conf}"
env

echo "Checking if postgres is up and ready for connections"
i=0
pg_isready -d ${URL} -t 60
PG_EXIT=$?
while [[ "${i}" -lt "5" && ${PG_EXIT} != 0 ]]
do
    echo "waiting for Postgres to start, attempt: ${i}"
    sleep 5s
    if [[ "${i}" > 5 ]]
    then
        echo "Error: failed waiting for Postgres to start"
        exit 1
    fi
    ((i++))
    pg_isready -d ${URL} -t 60
    PG_EXIT=$?
done


echo "Checking if database exists"
STATUS=$( psql ${URL} -tc "SELECT 1 FROM pg_database WHERE datname='${FLYWAY_PLACEHOLDERS_REFERENCEDBNAME}'" | sed -e 's/^[ \t]*//')
if [[ "${STATUS}" == "1" ]]
then
    echo "Database already exists"
else
    echo "Database does not exist creating - Bootstrapping databases"
    export FLYWAY_LOCATIONS="${FLYWAY_LOCATIONS_INIT}"
    flyway -configFiles="${FLYWAY_INIT_CONF}" migrate
    if [[ "$?" != 0 ]]
    then
        echo "Error: initialising database"
        exit 1
    fi

cat <<EOF >>/tmp/bootstrap.sql
\c $DB_NAME
CREATE SCHEMA $DB_SCHEMA AUTHORIZATION $DB_OWNERNAME;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" SCHEMA $FLYWAY_PLACEHOLDERS_REFERENCESCHEMA;
DROP SCHEMA public;
\c $DB_DEFAULT_NAME
REVOKE $DB_OWNERNAME FROM $FLYWAY_PLACEHOLDERS_MASTERUSER;
\q
EOF

    cat /tmp/bootstrap.sql
    psql ${URL} < /tmp/bootstrap.sql
    if [[ "$?" != 0 ]]
    then
        echo "Error: with bootstrapping database"
        exit 1
    fi
fi

echo "Starting migration of reference data"
export FLYWAY_URL="jdbc:postgresql://${DB_HOSTNAME}:${DB_PORT}/${FLYWAY_PLACEHOLDERS_REFERENCEDBNAME}${DB_JDBC_OPTIONS}"
export FLYWAY_USER="${FLYWAY_PLACEHOLDERS_REFERENCEOWNERNAME}"
export FLYWAY_PASSWORD="${FLYWAY_PLACEHOLDERS_REFERENCEOWNERPASSWORD}"
export FLYWAY_SCHEMAS="${FLYWAY_PLACEHOLDERS_REFERENCESCHEMA}"
export FLYWAY_PLACEHOLDERS_SCHEMA="${FLYWAY_PLACEHOLDERS_REFERENCESCHEMA}"
export FLYWAY_LOCATIONS="${FLYWAY_LOCATIONS_REFERENCE}"
export FLYWAY_PLACEHOLDERS_AUTHENTICATORUSER="${FLYWAY_PLACEHOLDERS_AUTHENTICATORUSER:=authuser}"
export FLYWAY_PLACEHOLDERS_AUTHENTICATORPASSWORD="${FLYWAY_PLACEHOLDERS_AUTHENTICATORPASSWORD:=authPwd}"
export FLYWAY_PLACEHOLDERS_ANONUSER="${FLYWAY_PLACEHOLDERS_ANONUSER:=anonuser}"
export FLYWAY_PLACEHOLDERS_READONLYUSER="${FLYWAY_PLACEHOLDERS_READONLYUSER:=readonlyuser}"
export FLYWAY_PLACEHOLDERS_SERVICEUSER="${FLYWAY_PLACEHOLDERS_SERVICEUSER:=serviceuser}"
export FLYWAY_PLACEHOLDERS_REPORTUSER="${FLYWAY_PLACEHOLDERS_REPORTUSER:=reportuser}"

env

flyway -configFiles="${FLYWAY_REFERENCE_CONF}" migrate
if [[ "$?" != 0 ]]
then
    echo "Error: migration of reference db failed"
    exit 1
fi

exit 0
