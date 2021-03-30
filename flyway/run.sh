#!/usr/bin/env bash

# Ensure environment values are not exposed in drone output
set +x

echo "Exporting environment variables"

export URL="postgresql://${FLYWAY_USER}:${FLYWAY_PASSWORD}@${DB_HOSTNAME}:${DB_PORT}/${DB_DEFAULT_NAME}${DB_OPTIONS}"
export FLYWAY_URL="jdbc:postgresql://${DB_HOSTNAME}:${DB_PORT}/${DB_DEFAULT_NAME}${DB_JDBC_OPTIONS}"

export FLYWAY_PLACEHOLDERS_MASTERUSER=${FLYWAY_USER}
export FLYWAY_PLACEHOLDERS_REFERENCEDBNAME=${DB_NAME}
export FLYWAY_PLACEHOLDERS_REFERENCEOWNERNAME=${DB_OWNERNAME}
export FLYWAY_PLACEHOLDERS_REFERENCEOWNERPASSWORD=${DB_OWNERPASSWORD}
export FLYWAY_PLACEHOLDERS_REFERENCESCHEMA=${DB_SCHEMA}

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
STATUS=$( psql ${URL} -tc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | sed -e 's/^[ \t]*//')
if [[ "${STATUS}" == "1" ]]
then
    echo "Database already exists"
else
    echo "Database does not exist creating - Bootstrapping databases"
    export FLYWAY_LOCATIONS="filesystem:/flyway/schemas/init"
    flyway -configFiles=/flyway/conf/init.conf migrate
    if [[ "$?" != 0 ]]
    then
        echo "Error: initialising database"
        exit 1
    fi

cat <<EOF >>/tmp/bootstrap.sql
\c $DB_NAME
CREATE SCHEMA $DB_SCHEMA AUTHORIZATION $DB_OWNERNAME;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" SCHEMA $DB_SCHEMA;
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
export FLYWAY_URL="jdbc:postgresql://${DB_HOSTNAME}:${DB_PORT}/${DB_NAME}${DB_JDBC_OPTIONS}"
export FLYWAY_USER=${DB_OWNERNAME}
export FLYWAY_PASSWORD=${DB_OWNERPASSWORD}
export FLYWAY_SCHEMAS=${DB_SCHEMA}
export FLYWAY_PLACEHOLDERS_SCHEMA=${DB_SCHEMA}
export FLYWAY_LOCATIONS="filesystem:/flyway/schemas/reference"

env

flyway -configFiles=/flyway/conf/reference.conf migrate
if [[ "$?" != 0 ]]
then
    echo "Error: migration of reference db failed"
    exit 1
fi

exit 0
