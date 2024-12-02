#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/m3d1/PVE-Scripts/refs/heads/main/misc/build.func)
# Copyright (c) 2024 M3d1
# Author: M3d1 (tteckster)
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

function header_info {
clear
cat <<"EOF"
   _____ ____    __    _____  _____  ______       __ _____  ______
  / ___// __ \  / /   / ___/ / ___/ /     / \    / // ___/ /     /
  \__ \/ / / / / /    \__ \ / ___/ / ____/ \ \  / // ___/ / ____/ 
 ___/ / /_/ / / /___ ___/ // /__  /  /\  \  \ \/ // /__  /  /\  \  
/____/\___\_\/_____//____//____/ /__/  \__\  \__//____/ /__/  \__\  
    
EOF
}

header_info
echo -e "Loading..."
APP="sqlserver"
var_disk="30"
var_cpu="4"
var_ram="4096"
var_os="ubuntu"
var_version="22.04"
vlan="101"
variables
color
catch_errors

function default_settings() {
  CT_TYPE="1"
  PW="P@ssw0rd!"
  CT_ID=$NEXTID
  HN=$NSAPP
  DISK_SIZE="$var_disk"
  CORE_COUNT="$var_cpu"
  RAM_SIZE="$var_ram"
  BRG="vmbr0"
  NET="dhcp"
  GATE=""
  APT_CACHER=""
  APT_CACHER_IP=""
  DISABLEIP6="no"
  MTU=""
  SD=""
  NS=""
  MAC=""
  VLAN="$vlan"
  SSH="yes"
  VERB="yes"
  echo_default
}

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
