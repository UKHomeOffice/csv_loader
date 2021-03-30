#!/usr/bin/env python3

from typing import Tuple, List

import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
# noinspection PyUnresolvedReferences
from psycopg2.errors import DuplicateDatabase, DuplicateObject, DuplicateTable
import os
import json
from json.decoder import JSONDecodeError
import configparser
from datetime import datetime

# connect and create db
host = os.getenv("POSTGRES_HOST", "postgres")
db_name = os.getenv("POSTGRES_DB", "ref")
user = os.getenv("POSTGRES_USER", "postgres")
password = os.getenv("POSTGRES_PASSWORD", "postgres")
schema = os.getenv("POSTGRES_SCHEMA", "public")
ref_conf = os.getenv("FLYWAY_REFERENCE_CONF", "/flyway/conf/reference.conf")
schema_locations = os.getenv("FLYWAY_LOCATIONS_REFERENCE", "/flyway/schemas/reference")

config = configparser.ConfigParser()
with open(ref_conf) as stream:
    config.read_string("[top]\n" + stream.read())

flyway_target = int(config["top"]["flyway.target"])

# reconnect to the reference database
conn = psycopg2.connect(host=host, database=db_name, user=user, password=password)
conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)


def find_and_sort_scripts() -> Tuple[List[str], int]:
    # find scripts
    _, _, files = next(os.walk(schema_locations))

    # sort by version number as integer
    files = [(fn, (int(fn[1:].split("_")[0]))) for fn in files
             if not fn.startswith("R")]
    sfiles = sorted(files, key=lambda t: t[1])

    return [x[0] for x in sfiles], sfiles[-1][1]


def list_tables() -> List[str]:
    # get list of tables
    cur = conn.cursor()
    cur.execute("select table_name from information_schema.tables where table_schema='public';")
    tables = cur.fetchall()
    tables = [x[0] for x in tables]
    tables.remove('flywayreferencehistory')
    return tables


def list_columns(table_name: str):
    cur = conn.cursor()
    cur.execute(
        f"select column_name, ordinal_position, data_type from information_schema.columns where table_name='{table_name}';")
    cols = cur.fetchall()

    cols = [(x[0], get_column_comment_json(cur, table_name, x[1])) for x in cols]

    cur.close()
    return cols


def get_table_comment_json(cur, table_name: str):
    cur.execute(f"select obj_description('public.{table_name}'::regclass)")
    jt = cur.fetchone()[0]

    try:
        j = json.loads(jt)
    except JSONDecodeError:
        return None

    return j


def get_column_comment_json(cur, table_name: str, column_index: str):
    cur.execute(f"select col_description('public.{table_name}'::regclass, {column_index});")
    jt = cur.fetchone()[0]
    if not jt:
        return None

    try:
        j = json.loads(jt)
    except JSONDecodeError:
        return None

    return j


def print_error(text: str, err_count: int, level=1) -> int:
    print(level * "  ", end="")
    print("!!!", end="")
    print(text)
    return err_count + 1


def check_j_present(j, props, err_count, level) -> int:
    for prop in props:
        if not j.get(prop):
            err_count = print_error(f"'{prop}' is missing", err_count, level)
    return err_count


def validate_tables(table_names: List[str]):
    err_count = 0
    cur = conn.cursor()
    for table in table_names:
        print(f"validating '{table}'")
        j = get_table_comment_json(cur, table)
        if not j:
            err_count = print_error("comment is not a valid JSON.", err_count)
            continue

        err_count = check_j_present(j,
                                    ["description", "schemalastupdated", "dataversion", "owner"],
                                    err_count, 1)

        # schemalastupdated is present and is in dd/MM/yyyy format
        schemalastupdated = j.get("schemalastupdated")
        if schemalastupdated:
            try:
                datetime.strptime(schemalastupdated, "%d/%m/%Y")
            except ValueError:
                err_count = print_error(
                    f"schemalastupdated needs to be in dd/MM/yyyy format, but the value found was '{schemalastupdated}'",
                    err_count)

        columns = list_columns(table)
        bk_cols = []
        # check json comment validity
        for column in columns:
            name = column[0]
            j = column[1]
            print(f"  validating '{name}'")
            if not j:
                err_count = print_error("comment is not a valid JSON", err_count, 2)
            else:
                err_count = check_j_present(j, ["label", "description"], err_count, 2)

                if j.get("businesskey"):
                    bk_cols.append(name)

        # there should be only one businesskey
        if len(bk_cols) != 1:
            if len(bk_cols):
                err_count = print_error(
                    f"exactly one column needs to have 'businesskey' attribute, following do: {bk_cols}",
                    err_count)
            else:
                err_count = print_error("one of the columns must have 'businesskey' attribute", err_count)

        # check we have validfrom and validto columns
        cnames = [x[0] for x in columns]
        if "validfrom" not in cnames:
            err_count = print_error("missing 'validfrom' column", err_count)
        if "validto" not in cnames:
            err_count = print_error("missing 'validto' column", err_count)

    return err_count


sfiles, sfiles_max = find_and_sort_scripts()

if sfiles_max != flyway_target:
    print(f"flyway.target in flyway/reference.conf is {flyway_target} but the last script number is {sfiles_max}")
    exit(1)


tables = list_tables()

err_count = validate_tables(tables)

if err_count:
    print(f"{err_count} error(s).")

exit(err_count)
