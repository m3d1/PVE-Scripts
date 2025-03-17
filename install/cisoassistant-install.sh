
#!/usr/bin/env bash

# Copyright (c) 2021-2025 m3d1
# Author: m3d1 (Mehdi BASRI)
# License: MIT
# https://github.com/m3d1/PVE-Scripts/raw/main/LICENSE

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y curl
$STD apt-get install -y sudo
$STD apt-get install -y mc
msg_ok "Installed Dependencies"

get_latest_release() {
  curl -sL https://api.github.com/repos/$1/releases/latest | grep '"tag_name":' | cut -d'"' -f4
}

DOCKER_LATEST_VERSION=$(get_latest_release "moby/moby")
PORTAINER_LATEST_VERSION=$(get_latest_release "portainer/portainer")
PORTAINER_AGENT_LATEST_VERSION=$(get_latest_release "portainer/agent")
DOCKER_COMPOSE_LATEST_VERSION=$(get_latest_release "docker/compose")

function install_docker()
{
msg_info "Installing Docker $DOCKER_LATEST_VERSION"
DOCKER_CONFIG_PATH='/etc/docker/daemon.json'
mkdir -p $(dirname $DOCKER_CONFIG_PATH)
echo -e '{\n  "log-driver": "journald"\n}' >/etc/docker/daemon.json
$STD sh <(curl -sSL https://get.docker.com)
msg_ok "Installed Docker $DOCKER_LATEST_VERSION"

read -r -p "Would you like to add Portainer? <y/N> " prompt
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
  msg_info "Installing Portainer $PORTAINER_LATEST_VERSION"
  docker volume create portainer_data >/dev/null
  $STD docker run -d \
    -p 8000:8000 \
    -p 9443:9443 \
    --name=portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest
  msg_ok "Installed Portainer $PORTAINER_LATEST_VERSION"
else
  read -r -p "Would you like to add the Portainer Agent? <y/N> " prompt
  if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
    msg_info "Installing Portainer agent $PORTAINER_AGENT_LATEST_VERSION"
    $STD docker run -d \
      -p 9001:9001 \
      --name portainer_agent \
      --restart=always \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v /var/lib/docker/volumes:/var/lib/docker/volumes \
      portainer/agent
    msg_ok "Installed Portainer Agent $PORTAINER_AGENT_LATEST_VERSION"
  fi
fi
}

function install_ciso()
{
## Ciso Assistant Script part
# Cloning Github Project Repo
mkdir -p /opt/ciso-sources/
cd /opt/ciso-sources/

#install python
$STD apt install python3-pip python3.12-venv

#clone the repo
git clone https://github.com/intuitem/ciso-assistant-community.git

#go to the config generator
cd ciso-assistant-community
cd config

# setting up the python project and dependencies 
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# run the interactive config generator
python make_config.py

$STD ./docker-compose.sh
}


msg_info "use : cat cisoassistant.creds to retreive all the credentials"
}

install_docker
install_ciso

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
