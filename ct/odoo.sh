@ -0,0 +1,71 @@
#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/m3d1/PVE-Scripts/refs/heads/main/misc/build.func)
# Copyright (c) 2024 M3d1
# Author: Mehdi BASRI (M3d1)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

APP="odoo"
var_tags="erp;accounting"
var_disk="40"
var_cpu="4"
var_ram="4096"
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
  if [[ ! -d /usr/share/odoo ]]; then 
    msg_error "No ${APP} Installation Found!"; 
    exit;
  fi
  msg_error "To update ${APP}, use the applications web interface."
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
