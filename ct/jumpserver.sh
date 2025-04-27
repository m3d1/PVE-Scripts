@ -0,0 +1,71 @@
#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/m3d1/PVE-Scripts/refs/heads/main/misc/build.func)
# Copyright (c) 2025 M3d1
# Author: Mehdi BASRI (M3d1)
# License: MIT
# https://github.com/m3d1/ProxmoxVE/raw/main/LICENSE

function header_info {
clear
cat <<"EOF"
    ___  ___  ___  _____ ______   ________  ________  _______   ________  ___      ___ _______   ________     
   |\  \|\  \|\  \|\   _ \  _   \|\   __  \|\   ____\|\  ___ \ |\   __  \|\  \    /  /|\  ___ \ |\   __  \    
   \ \  \ \  \\\  \ \  \\\__\ \  \ \  \|\  \ \  \___|\ \   __/|\ \  \|\  \ \  \  /  / | \   __/|\ \  \|\  \   
 __ \ \  \ \  \\\  \ \  \\|__| \  \ \   ____\ \_____  \ \  \_|/_\ \   _  _\ \  \/  / / \ \  \_|/_\ \   _  _\  
|\  \\_\  \ \  \\\  \ \  \    \ \  \ \  \___|\|____|\  \ \  \_|\ \ \  \\  \\ \    / /   \ \  \_|\ \ \  \\  \| 
\ \________\ \_______\ \__\    \ \__\ \__\     ____\_\  \ \_______\ \__\\ _\\ \__/ /     \ \_______\ \__\\ _\ 
 \|________|\|_______|\|__|     \|__|\|__|    |\_________\|_______|\|__|\|__|\|__|/       \|_______|\|__|\|__|
                                              \|_________|                                                    
    
EOF
}
header_info
echo -e "Loading..."
APP="jumpserver"
var_tags="pam"
var_disk="60"
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
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following IP:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}${IP}:3306${CL}"