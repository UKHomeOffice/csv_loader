# Reference data governance service

## Database schema design

Each Table must contain a comment in JSON format containing the following entities:

* description
* schemalastupdated
* dataversion
* `owner` - a group email like `owner@example.com`

and these columns are required:

* validfrom
* validto


Each Column must contain a comment in JSON format containing the following entities:

* label
* description

One column must also contain the comment:

* businesskey: "true"

Optional entities for column comments:

* aliases (comma separated list)
* minimumlength
* maximumlength
* minimumvalue
* maximumvalue

*There should be NO CSVs or Schemas checked into this repo*, the ones here are samples. It is recommended that schemas
and csvs should be put into separate repos. This docker image can then be used as a base image or with the 
docker-compose.general.yml to override the locations.

## Grants

Each table must have at least two GRANTs, as follows:
* serviceuser - This used by Camunda to allow new records to be added to the Reference data and current records to be updated.
* readonlyuser - This user can read all records.
* anonuser - This user should only be added to public tables where authentication is not needed to see the data.
  This should be the default for all datasets unless they are deemed sensitive.


### Example

```sql
CREATE TABLE ministry (
  id INTEGER NOT NULL PRIMARY KEY,
  name VARCHAR(60) NOT NULL,
  code VARCHAR(8) NOT NULL,
  validfrom TIMESTAMP WITH TIME ZONE,
  validto TIMESTAMP WITH TIME ZONE,
  updatedby VARCHAR(60) NULL
);

-- Table comment
COMMENT ON TABLE ministry IS '{"label": "Government ministries", "owner": "xyx@test.com", "description": "A list of departments, agencies and public bodies.", "schemalastupdated": "06/03/2019", "dataversion": 1}';
-- Column comments
COMMENT ON COLUMN ministry.id IS '{"label": "Identifier", "description": "Database unique identity record."}';
COMMENT ON COLUMN ministry.name IS '{"label": "Name", "description": "The name of the branch or region."}';
COMMENT ON COLUMN ministry.code IS '{"label": "Code", "businesskey": true, "description": "The code associated with the branch or region."}';
COMMENT ON COLUMN ministry.validfrom IS '{"label": "Valid from date", "description": "Item valid from date."}';
COMMENT ON COLUMN ministry.validto IS '{"label": "Valid to date", "description": "Item valid to date."}';
COMMENT ON COLUMN ministry.updatedby IS '{"label": "Updated By", "description": "Record updated by"}';

-- GRANTs
GRANT SELECT,INSERT,UPDATE ON ministry TO ${serviceuser};
GRANT SELECT ON ministry TO ${readonlyuser};
GRANT SELECT ON ministry TO ${anonuser};
```



## Environment variables

* DB_HOSTNAME
* DB_PORT
* DB_NAME
* DB_DEFAULT_NAME
* DB_OPTIONS
* DB_JDBC_OPTIONS
* FLYWAY_USER
* FLYWAY_PASSWORD
* DB_OWNERNAME
* DB_OWNERPASSWORD
* DB_SCHEMA
* FLYWAY_PLACEHOLDERS_AUTHENTICATORUSER
* FLYWAY_PLACEHOLDERS_AUTHENTICATORPASSWORD
* FLYWAY_PLACEHOLDERS_ANONUSER
* FLYWAY_PLACEHOLDERS_SERVICEUSER
* FLYWAY_PLACEHOLDERS_READONLYUSER

## Development

### Setting Up

#### Required dependencies (Ubuntu)

```
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-key C99B11DEB97541F0
sudo apt-add-repository https://cli.github.com/packages
sudo apt update
snap install docker
sudo groupadd docker
sudo chgrp docker /var/run/docker.sock
sudo apt install git vim jq curl postgresql-client-common postgresql-client-12 gh
```


### useful

- [Get Postman](https://www.postman.com/downloads/)



## Start up Docker


### Stage 1

Start the supporting services.

```bash
docker-compose -f docker-compose.yml -f docker-compose.general.yml up -d db keycloak
```


Go to the following url [http://localhost:8080/auth/admin/master/console/#/realms/rocks/users](http://localhost:8080/auth/admin/master/console/#/realms/rocks/users) 
Login as admin/admin.
Create a new user called demo with the following settings:
* username: demo
* email: demo@localhost
* first name: demo
* last name: demo
* email verified: true
  Select save then on the credentials tab set the password to 'demo' and set Temporary to false and set the password.



### Stage 2

Once the services are online you can next seed the database using flyway.

```bash
docker-compose -f docker-compose.yml -f docker-compose.general.yml up flyway
```

To validate the schemas you can run

```bash
docker-compose -f docker-compose.yml -f docker-compose.general.yml up validate
```



### Stage 3

#### JWT keysetup for postgres

Execute the following command to get the correct JWT key then use the output of the echo as the value in 
docker-compose.general.yml file for the key postgrest.environment.PGRST_JWT_SECRET

```bash
export JWT="$(curl -s http://localhost:8080/auth/realms/rocks/protocol/openid-connect/certs \
| jq -rc '.keys | first | {kid, kty, alg, n, e}')"
echo $JWT
```

Start API server and load the CSV's

```bash
docker-compose -f docker-compose.yml -f docker-compose.general.yml up -d postgrest
```


### Stage 4

Load the initial CSV reference data

```bash
docker-compose -f docker-compose.yml -f docker-compose.general.yml up csv_loader
```



You can clean up the docker by either running the *./cleanup.sh* script or if you just want to reset the reference data
schemas you can run *./drop_db.sh*


### Making Changes

1. Create a new flyway file in *flyway/schemas/reference* - 
   follow [flyway documentation](https://flywaydb.org/documentation/) if you are not familiar with this system. 
   Look at the existing scripts and try to be like a ninja - make your scripts blend in.
2. Change `flyway.target` in *flyway/reference.conf* to your script number.
3. Raise a PR and wait for validation to complete. Check build logs if anything goes wrong - 
   you will get a detailed reason why something is not working.
