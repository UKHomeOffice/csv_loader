FROM openjdk:11.0.11-jre

ENV FLYWAY_VERSION 7.3.0
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/flyway:/usr/bin:${PATH}"
ENV PYTHONPATH="/python:${PYTHONPATH}"
ENV LANG en_GB.utf8

RUN apt update -y \
    && apt upgrade -y \
    && apt install -y curl

RUN cd /usr/bin \
  && curl -L https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/${FLYWAY_VERSION}/flyway-commandline-${FLYWAY_VERSION}.tar.gz -o flyway-commandline-${FLYWAY_VERSION}.tar.gz \
  && tar -xzf flyway-commandline-${FLYWAY_VERSION}.tar.gz --strip-components=1 \
  && rm flyway-commandline-${FLYWAY_VERSION}.tar.gz \
  && chmod +x /usr/bin/*

COPY flyway /flyway
COPY validation /validation
COPY csvs/ /csvs
COPY requirements.txt /tmp/requirements.txt
COPY environment.json /environment.json

RUN useradd -m java

RUN apt update -y \
    && apt upgrade -y \
    && apt install -y software-properties-common git locales gnupg python3-pip libpq-dev openssl ca-certificates bash postgresql-client \
    && apt update -y \
    && localedef -i en_GB -c -f UTF-8 -A /usr/share/locale/locale.alias en_GB.UTF-8a \
    && python3 -m pip install -r /tmp/requirements.txt \
    && apt remove -y python3-pip \
    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && chown -R java:java /home/java /flyway /validation /csvs /environment.json \
    && chmod +x /validation/validate.py /csvs/load_csvs.py

USER java
WORKDIR /
