#!/usr/bin/env python3

import argparse
import requests
import yaml
from datetime import datetime
from typing import List
from rich import print, pretty

pretty.install()

def init_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("-u", "--username", help="username")
    parser.add_argument("-p", "--password", help="password")
    parser.add_argument("-s", "--server", help="Postgrest server url", default="http://localhost:3000")
    parser.add_argument("-e", "--environment", default="local",
                        choices=["local", "dev", "staging", "production"],
                        help=' '.join(["Specify the type of environment this is to be deployed in, ",
                                      "Valid choices are: local, dev, staging, production"]))
    args = parser.parse_args()
    return args


def get_token():
    username = args.username
    password = args.password
    environment = args.environment
    from keycloak import KeycloakOpenID

#TODO load env from json

    # Get Token
    token = keycloak_openid.token(username, password)
    return token, keycloak_openid


def add_auth(header, token=None):
    if token:
        access_token = token['access_token']
        header["Authorization"] = f"Bearer {access_token}"


def query(table: str, filename: str, dir: str, is_upsert=False, token=None):
    print(f"⬆ uploading '{filename}' to table '{table}'...", end="")
    header = {
        "Content-Type": "text/csv"
    }

    if is_upsert:
        header["Prefer"] = "resolution=merge-duplicates"

    add_auth(header, token=token)

    with open(f"{dir}/{filename}", "r", encoding="utf-8") as fn:
        csv = fn.read()

    r = requests.post(f"{args.server}/{table}", headers=header, data=csv.encode("utf-8"))
    
    if r.status_code != 201:
        raise Exception(r.text)

    print(f"[OK]")


def load_applied_scripts(token=None) -> List[str]:
    headers = {}
    add_auth(headers, token=token)

    j = requests.get(f"{args.server}/_data_change_history", headers=headers).json()
    return list(set([x["scriptname"] for x in j]))


def save_state(filename: str, token=None):
    headers = {"Content-Type": "application/json"}
    add_auth(headers, token=token)
    data = {
        "scriptname": filename,
        "updatedby": "drone"
    }
    r = requests.post(f"{args.server}/_data_change_history", headers=headers, json=data)


def main():
    token = None
    keycloak_openid = None
    is_local_dev = args.environment == "local"
    if not is_local_dev:
        token, keycloak_openid = get_token()
    applied_scripts = load_applied_scripts(token=token)
    do_init = len(applied_scripts) == 0  # so that migration from "--init" flag works

    print(f"environment: {args.environment} (local: {is_local_dev})")
    print(f"server:      {args.server}")
    print(f"username:    {args.username}")
    print(f"do init:     {do_init}")


    with open(r'load_order.yaml') as f:
        documents = yaml.full_load(f)

    init_documents = documents.get("init")
    patch_documents = documents.get("patch")
    print(f"{len(init_documents)} init script(s) and {len(patch_documents)} patch(es).")

    if do_init:
        for item in init_documents:
            table = item["table"]
            filename = item["csv"]
            query(table, filename, "csvs/initial", False, token=token)
        save_state("init", token=token)

    if patch_documents:
        for item in patch_documents:
            table = item["table"]
            filename = item["csv"]

            if filename in applied_scripts:
                print(f"[bold]{filename}[/bold] [underline]already[/underline] applied.")
            else:
                query(table, filename, "csvs/patch", True, token=token)
                save_state(filename, token=token)       

    # # Refresh token
    # token = keycloak_openid.refresh_token(token['refresh_token'])

    # Logout
    if not is_local_dev:
        keycloak_openid.logout(token['refresh_token'])


if __name__ == "__main__":
    args = init_args()
    main()

