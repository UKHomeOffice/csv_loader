FROM ubuntu:20.04

COPY . /app
WORKDIR /app


ENV DEBIAN_FRONTEND=noninteractive

RUN apt update -y \
    && apt upgrade -y \
    && apt install -y software-properties-common locales gnupg python3-pip \
    && apt update -y \
    && localedef -i en_GB -c -f UTF-8 -A /usr/share/locale/locale.alias en_GB.UTF-8a \
    && python3 -m pip install -r requirements.txt \
    && apt remove -y python3-pip \
    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -r user && useradd --no-log-init -r -g user user

USER user

ENV LANG en_GB.utf8

ENTRYPOINT [ "python3", "run.py"]
