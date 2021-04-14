from dearpygui.core import *
from dearpygui.simple import *
from dearpygui.demo import show_demo
import docker
import threading
import time
import webbrowser
import requests
import json
import os
import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
# noinspection PyUnresolvedReferences
from psycopg2.errors import DuplicateDatabase, DuplicateObject, DuplicateTable

running = True
watched_containers = []
windows = set()
container_name_to_id = {}
USE_COMPOSE = True


def start_container(sender, name):
    log_info(f"starting container {name}")
    if USE_COMPOSE:
        os.system(f"docker-compose -f docker-compose.yml -f docker-compose.general.yml up -d {name}")
    else:
        id = container_name_to_id[name]
        container = dc.containers.get(id)
        container.start()


def stop_container(sender, name):
    log_info(f"stopping container {name}")
    if USE_COMPOSE:
        os.system(f"docker-compose stop {name}")
    else:
        id = container_name_to_id[name]
        container = dc.containers.get(id)
        container.stop()


def view_container_logs(sender, name):
    rf_name = f"{name}#log#refresh"
    tx_name = f"{name}#log#text"

    def refresh_logs(sender1, data1):
        log_info(f"fetching logs for container {name}")
        id = container_name_to_id[name]
        container = dc.containers.get(id)
        lines = container.logs()  # bytes
        tx_lines = lines.decode("utf-8")
        log_info(f"setting for {rf_name}: {len(tx_lines)} char(s).")
        set_value(tx_name, tx_lines)

    window_name = f"{name}#logs#window"

    if window_name not in get_windows():
        with window(window_name, label=f"Logs :: {name}", width=610, height=400):
            add_button(rf_name, label="refresh", callback=refresh_logs, callback_data=name)
            add_input_text(tx_name, multiline=True, label="", width=600, height=340)

    refresh_logs(None, rf_name)
    show_item(window_name)


def add_status_report(name: str):
    # add_text(f"{name}#status")
    watched_containers.append(name)
    lbl_name = f"{name}#status"
    add_label_text(lbl_name, label="unknown")
    set_item_width(lbl_name, 80)

    add_button(f"{name}#start", label="start", callback=start_container, callback_data=name)
    add_same_line()
    add_button(f"{name}#stop", label="stop", callback=stop_container, callback_data=name)
    add_same_line()
    add_button(f"{name}#logs", label="logs", callback=view_container_logs, callback_data=name)


def set_status_report(name: str, status: str):
    ename = f"{name}#status"
    # set_value(ename, status)
    set_item_label(ename, status.upper())


def get_jwt(sender, data):
    key = requests.get("http://localhost:8080/auth/realms/rocks/protocol/openid-connect/certs").json()["keys"][0]
    key = {
        "kid": key["kid"],
        "kty": key["kty"],
        "alg": key["alg"],
        "n": key["n"],
        "e": key["e"]
    }
    j_key = json.dumps(key)
    print(j_key)
    set_value("keycloak#jwt", j_key)


def refresh_table_list(sender, data):
    # reconnect to the reference database
    conn = psycopg2.connect(host="db", database="ref", user="postgres", password="postgres")
    conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)



with window("window#schema", label="Schema Browser", width=600):
    add_combo("schema#tables", label="table")
    add_same_line()
    add_button("schema#tables#refresh", label="refresh")


def open_schema_browser(sender, data):
    show_item("window#schema")


with window("Main"):

    with menu_bar("menu#main"):
        with menu("menu#db", label="DB"):
            add_menu_item("menu#db#schema", label="Schema Browser", callback=open_schema_browser)
            add_menu_item("menu#db#view", label="Data Viewer")

    with node_editor("servers"):
        with node("db", label="DB", x_pos=30, y_pos=80):
            with node_attribute("db#out", output=True):
                add_status_report("db")

        with node("flyway", label="Schema Loader", x_pos=260, y_pos=10):
            with node_attribute("flyway#in"):
                add_status_report("flyway")
            with node_attribute("flyway#out", output=True):
                pass

        with node("validate", label="Schema Validator", x_pos=450, y_pos=80):
            with node_attribute("validate#in"):
                add_status_report("validate")

        with node("keycloak", label="Keycloak", x_pos=200, y_pos=250):
            with node_attribute("keycloak#in"):
                add_status_report("keycloak")
                add_button("keycloak#browser", label="admin console",
                           callback=lambda s, d: webbrowser.open(
                               "http://localhost:8080/auth/admin/master/console/#/realms/rocks/users"))
                add_button("keycloak#getjwt", label="get JWT token",
                           callback=get_jwt)
                add_input_text("keycloak#jwt", width=200, label="")
            with node_attribute("keycloak#out", output=True):
                pass

        with node("postgrest", label="PostgREST", x_pos=500, y_pos=220):
            with node_attribute("postgrest#in"):
                add_status_report("postgrest")
            with node_attribute("postgrest#out", output=True):
                pass

        with node("csv_loader", label="CSV Loader", x_pos=700, y_pos=350):
            with node_attribute("csv_loader#in"):
                add_status_report("csv_loader")

    add_node_link("servers", "db#out", "flyway#in")
    add_node_link("servers", "db#out", "validate#in")
    add_node_link("servers", "flyway#out", "validate#in")

    add_node_link("servers", "db#out", "keycloak#in")
    add_node_link("servers", "keycloak#out", "postgrest#in")
    add_node_link("servers", "db#out", "postgrest#in")

    add_node_link("servers", "keycloak#out", "csv_loader#in")
    add_node_link("servers", "postgrest#out", "csv_loader#in")

set_main_window_title("Ref Data")

dc = docker.from_env()


def background():
    while running:
        containers = dc.containers.list(all=True)
        for c in containers:
            container_name_to_id[c.name] = c.id
            if c.name not in watched_containers:
                continue
            set_status_report(c.name, c.status)

        time.sleep(2)


# show_logger()
# show_demo()
bg = threading.Thread(name="background", target=background)
bg.start()
start_dearpygui(primary_window="Main")
running = False
