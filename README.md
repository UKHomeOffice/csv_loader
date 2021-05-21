# CSV Loader

This is a helper repository showing how to manage data schemas and data itself and set up services for managing them.

*There should be NO CSVs or Schemas checked into this repo*, the ones here are samples. It is recommended that schemas
and csvs should be put into separate repos. This docker image can then be used as a base image or with the 
docker-compose.general.yml to override the locations.

# Setting Up

## Prerequisites

- Docker & Docker Compose (on Linux, you may need to [update Compose separately](https://docs.docker.com/compose/install/#install-compose)).

### Required dependencies (Ubuntu)

```bash
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

# Schema and Data Prerequisites

If you follow this guide, keep in mind that `docker-compose.general.yml` expects the following directory structure on your local disk:

- `flyway` - schema definitions. There is a folder in current repository with sample schema. Most probably you would clone [RefData Schema]([UKHomeOffice/RefData: Reference data and schema for RefData project stream (github.com)](https://github.com/UKHomeOffice/RefData)) as `flyway` folder (`git clone git@github.com:UKHomeOffice/RefData.git flyway`).
- `csv` - data scripts. Current repo's `csvs` folder contains a sample of those. You will most likely clone [csv repo]([cop / csv · GitLab (digital.homeoffice.gov.uk)](https://gitlab.digital.homeoffice.gov.uk/cop/csv))  as `csv`.
- `csv_loader` - **this repo**. 

![](media/folders.png)

Note the picture above - csv_loader (this repo, #3) contains "flyway" and "csvs" as subfolders, but those are not the folders you need. #1 and #2 have to be cloned on the same directory level as "csv_loader".

## Start up Docker


### Stage 1

Start Postgres database:

```bash
docker-compose -f docker-compose.yml -f docker-compose.general.yml up -d db
```

Start Keycloak:

```bash
docker-compose -f docker-compose.yml -f docker-compose.general.yml up -d keycloak
```

No that keycloak is a heavy piece of software and it may take a couple of minutes for it to become available.

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
