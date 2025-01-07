@ -0,0 +1,71 @@
#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/m3d1/PVE-Scripts/refs/heads/main/misc/build.func)
# Copyright (c) 2024 M3d1
# Author: Mehdi BASRI (M3d1)
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

function header_info {
clear
cat <<"EOF"
 ________  ________  ___               ________  _______   ________  ___      ___ _______   ________     
|\   ____\|\   __  \|\  \             |\   ____\|\  ___ \ |\   __  \|\  \    /  /|\  ___ \ |\   __  \    
\ \  \___|\ \  \|\  \ \  \            \ \  \___|\ \   __/|\ \  \|\  \ \  \  /  / | \   __/|\ \  \|\  \   
 \ \_____  \ \  \\\  \ \  \            \ \_____  \ \  \_|/_\ \   _  _\ \  \/  / / \ \  \_|/_\ \   _  _\  
  \|____|\  \ \  \\\  \ \  \____        \|____|\  \ \  \_|\ \ \  \\  \\ \    / /   \ \  \_|\ \ \  \\  \| 
    ____\_\  \ \_____  \ \_______\        ____\_\  \ \_______\ \__\\ _\\ \__/ /     \ \_______\ \__\\ _\ 
   |\_________\|___| \__\|_______|       |\_________\|_______|\|__|\|__|\|__|/       \|_______|\|__|\|__|
   \|_________|     \|__|                \|_________|                                                    
                                                                                                             
EOF
}
header_info
echo -e "Loading..."
APP="sqlserver"
var_tags="database"
var_disk="10"
var_cpu="2"
var_ram="2048"
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