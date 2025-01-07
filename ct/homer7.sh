#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/m3d1/PVE-Scripts/refs/heads/main/misc/build.func)
# Copyright (c) 2021-2024 m3d1
# Author: mehdi BASRI (m3d1)
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

function header_info {
clear
cat <<"EOF"
 ___  ___  ________  _____ ______   _______   ________          ________  
|\  \|\  \|\   __  \|\   _ \  _   \|\  ___ \ |\   __  \        |\_____  \ 
\ \  \\\  \ \  \|\  \ \  \\\__\ \  \ \   __/|\ \  \|\  \        \|___/  /|
 \ \   __  \ \  \\\  \ \  \\|__| \  \ \  \_|/_\ \   _  _\           /  / /
  \ \  \ \  \ \  \\\  \ \  \    \ \  \ \  \_|\ \ \  \\  \|         /  / / 
   \ \__\ \__\ \_______\ \__\    \ \__\ \_______\ \__\\ _\        /__/ /  
    \|__|\|__|\|_______|\|__|     \|__|\|_______|\|__|\|__|       |__|/   

EOF
}
header_info
echo -e "Loading..."
APP="homer7"
TAGS="network;voip"
var_disk="50"
var_cpu="4"
var_ram="4096"
var_os="debian"
var_version="12"
var_unprivileged="1"

# App Output & Base Settings
header_info "$APP"
base_settings

# Core
variables
color
catch_errors


function update_script() {
header_info
check_container_storage
check_container_resources
if [[ ! -d /var ]]; then msg_error "No ${APP} Installation Found!"; exit; fi
msg_info "Updating $APP LXC"
apt-get update &>/dev/null
apt-get -y upgrade &>/dev/null
msg_ok "Updated $APP LXC"
exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
