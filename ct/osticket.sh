#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/m3d1/PVE-Scripts/main/misc/build.func)
# Copyright (c) 2021-2024 M3d1
# Author: M3d1 (M3d1)
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

function header_info {
clear
cat <<"EOF"
 ________  ________  _________  ___  ________  ___  __    _______  _________   
|\   __  \|\   ____\|\___   ___|\  \|\   ____\|\  \|\  \ |\  ___ \|\___   ___\ 
\ \  \|\  \ \  \___|\|___ \  \_\ \  \ \  \___|\ \  \/  /|\ \   __/\|___ \  \_| 
 \ \  \\\  \ \_____  \   \ \  \ \ \  \ \  \    \ \   ___  \ \  \_|/__  \ \  \  
  \ \  \\\  \|____|\  \   \ \  \ \ \  \ \  \____\ \  \\ \  \ \  \_|\ \  \ \  \ 
   \ \_______\____\_\  \   \ \__\ \ \__\ \_______\ \__\\ \__\ \_______\  \ \__\
    \|_______|\_________\   \|__|  \|__|\|_______|\|__| \|__|\|_______|   \|__|
             \|_________|                                                      
                                
EOF
}
header_info
echo -e "Loading..."
APP="osticket"
var_tags="ticketing"
var_disk="2"
var_cpu="2"
var_ram="1024"
var_os="ubuntu"
var_version="22.04"
var_unprivileged="1"

# App Output & Base Settings
header_info "$APP"
base_settings

# Core
variables
color
catch_errors
variables
color
catch_errors


function update_script() {
header_info
check_container_storage
check_container_resources
if [[ ! -d /var ]]; then msg_error "No ${APP} Installation Found!"; exit; fi
msg_info "Updating ${APP} LXC"
apt-get update &>/dev/null
apt-get -y upgrade &>/dev/null
msg_ok "Updated ${APP} LXC"
exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
