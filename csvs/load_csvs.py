#!/usr/bin/env python3

import argparse
import requests
import yaml
from datetime import datetime
from typing import List
from rich import print, pretty
import json

pretty.install()

def init_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("-u", "--username", help="username", default="demo")
    parser.add_argument("-p", "--password", help="password", default="demo")
    parser.add_argument("-e", "--environment", default="docker",
                        choices=["docker", "local", "dev", "staging", "production"],
                        help=' '.join(["Specify the type of environment this is to be deployed in, ",
                                      "Valid choices are: docker, local, dev, staging, production"]))
    args = parser.parse_args()
    return args


def get_token(envs):
    username = args.username
    password = args.password
    from keycloak import KeycloakOpenID

    print(f"Auth Url:      {envs['auth']['url']}")
    print(f"Auth ClientId:      {envs['auth']['clientId']}")
    print(f"Auth Realm:      {envs['auth']['realm']}")

    keycloak_openid = KeycloakOpenID(server_url=envs['auth']['url'],
                                     client_id=envs['auth']['clientId'],
                                     realm_name=envs['auth']['realm'])

    # Get Token
    token = keycloak_openid.token(username, password)
    return token, keycloak_openid


def add_auth(header, token=None):
    if token:
        access_token = token['access_token']
        header["Authorization"] = f"Bearer {access_token}"


def query(table: str, filename: str, dir: str, server, is_upsert=False, token=None):
    print(f"⬆ uploading '{filename}' to table '{table}'...", end="")
    header = {
        "Content-Type": "text/csv"
    }

    if is_upsert:
        header["Prefer"] = "resolution=merge-duplicates"

    add_auth(header, token=token)

    with open(f"{dir}/{filename}", "r", encoding="utf-8") as fn:
        csv = fn.read()

    r = requests.post(f"{server}/{table}", headers=header, data=csv.encode("utf-8"))

    if r.status_code != 201:
        raise Exception(r.text)

    print(f"[OK]")


def load_applied_scripts(server, token=None) -> List[str]:
    headers = {}
    add_auth(headers, token=token)

    j = requests.get(f"{server}/_data_change_history", headers=headers).json()
    return list(set([x["scriptname"] for x in j]))


def save_state(filename: str, server, token=None):
    headers = {"Content-Type": "application/json"}
    add_auth(headers, token=token)
    data = {
        "scriptname": filename,
        "updatedby": "drone"
    }
    r = requests.post(f"{server}/_data_change_history", headers=headers, json=data)


def refresh_views(server, token=None):
    headers = {"Content-Type": "application/json"}
    add_auth(headers, token=token)
    data = {"schema_arg": "public"}
    print("Refreshing materialized views")
    r = requests.post(f"{server}/rpc/refreshallmaterializedviews", headers=headers, json=data)

    if r.status_code != 200:
        raise Exception(r.text)

    print(f"[OK]")

def main():
    token = None
    keycloak_openid = None
    is_local_dev = args.environment == "local"

    with open('../environment.json', 'r') as environmentFile:
        environmentData=environmentFile.read()

    args.environment
    envs = json.loads(environmentData)[args.environment]
    server = envs['server']

    print(f"environment: {args.environment} (local: {is_local_dev})")
    print(f"server:      {server}")
    print(f"username:    {args.username}")

    if not is_local_dev:
        token, keycloak_openid = get_token(envs)
    applied_scripts = load_applied_scripts(server, token=token)
    do_init = len(applied_scripts) == 0  # so that migration from "--init" flag works

    print(f"do init:     {do_init}")

    with open(r'/csvs/load_order.yaml') as f:
        documents = yaml.full_load(f)

    init_documents = documents.get("init")
    patch_documents = documents.get("patch")


    if do_init:
        print(f"{len(init_documents)} init script(s)")
        for item in init_documents:
            table = item["table"]
            filename = item["csv"]
            query(table, filename, "/csvs/initial", server, False, token=token)
        save_state("init", server, token=token)

    if patch_documents:
        print(f"{len(patch_documents)} patch(es).")
        for item in patch_documents:
            table = item["table"]
            filename = item["csv"]

            if filename in applied_scripts:
                print(f"[bold]{filename}[/bold] [underline]already[/underline] applied.")
            else:
                query(table, filename, "/csvs/patch", server, True, token=token)
                save_state(filename, server, token=token)

    refresh_views(server, token=token)

    if not is_local_dev:
        keycloak_openid.logout(token['refresh_token'])


if __name__ == "__main__":
    args = init_args()
    main()

