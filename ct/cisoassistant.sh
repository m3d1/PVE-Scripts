#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/m3d1/PVE-Scripts/refs/heads/cisoassistant-docker/misc/build.func)
# Copyright (c) 2025 M3d1
# Author: Mehdi BASRI (M3d1)
# License: MIT
# https://github.com/m3d1/ProxmoxVE/raw/main/LICENSE

APP="cisoassistant"
var_tags="GRC"
var_cpu="4"
var_ram="4096"
var_disk="40"
var_os="ubuntu"
var_version="24.04"
var_unprivileged="1"

header_info "$APP"
variables
color
catch_errors

function update_script() {
    header_info
    check_container_storage
    check_container_resources
    if [[ ! -d /var ]]; then
        msg_error "No ${APP} Installation Found!"
        exit
    fi
    msg_info "Updating ${APP} LXC"
    $STD apt-get update
    $STD apt-get -y upgrade
    msg_ok "Updated ${APP} LXC"
    exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"