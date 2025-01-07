#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2024 M3di1
# Author: M3di1 (M3di1)
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

function header_info {
clear
cat <<"EOF"
 ________  ___       ________  ___     
|\   ____\|\  \     |\   __  \|\  \    
\ \  \___|\ \  \    \ \  \|\  \ \  \   
 \ \  \  __\ \  \    \ \   ____\ \  \  
  \ \  \|\  \ \  \____\ \  \___|\ \  \ 
   \ \_______\ \_______\ \__\    \ \__\
    \|_______|\|_______|\|__|     \|__|
 
EOF
}
header_info
echo -e "Loading..."
APP="GLPI"
var_tags="ITAD;foss"
var_disk="2"
var_cpu="2"
var_ram="1024"
var_os="ubuntu"
var_version="22.04"
var_unprivileged="1"
variables
color
catch_errors

function default_settings() {
  CT_TYPE="1"
  PW=""
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
  VLAN=""
  SSH="no"
  VERB="no"
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
