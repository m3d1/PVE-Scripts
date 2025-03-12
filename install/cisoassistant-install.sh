
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
DOMAIN=""
FQDN=""
IPADRESS=$(ip addr show $INTERFACE | grep inet | awk '{ print $2; }' | sed 's/\/.*$//' | head -n 1)
HOST=$(hostname)

#Prompt
msg_info "CISO Assistant need to be configured with a FQDN that can be resolved by a dns server , Make sure that the domaine bellow is recheable"
read -r -p "Provide a domain name (ex: skynet.local) :" DOMAIN
FQDN=$HOST+"."+$DOMAIN
msg_info "your A record should contain the following information : IP : $IPADRESS , FQDN : $FQDN "

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
git clone https://github.com/intuitem/ciso-assistant-community.git
## Replace default local value with remote details
ALLOWED_HOSTS="      - ALLOWED_HOSTS=backend,$hostname"
CISO_ASSISTANT_URL="      - CISO_ASSISTANT_URL=https://$FQDN:8443"
PUBLIC_BACKEND_URL="      - PUBLIC_BACKEND_API_URL=http://$FQDN:8000/api"
PUBLIC_BACKEND_API="      - PUBLIC_BACKEND_API_EXPOSED_URL=https://$FQDN:8443/api"
sed -i -e "s/      - ALLOWED_HOSTS=backend,localhost/$ALLOWED_HOSTS/g" docker-compose.yml
sed -i -e "s/      - CISO_ASSISTANT_URL=https://localhost:8443/$CISO_ASSISTANT_URL/g" docker-compose.yml
sed -i -e "s/      - PUBLIC_BACKEND_API_URL=http://backend:8000/api/$PUBLIC_BACKEND_UR/g" docker-compose.yml
sed -i -e "s/      - PUBLIC_BACKEND_API_EXPOSED_URL=https://localhost:8443/api/$PUBLIC_BACKEND_API/g" docker-compose.yml
# start installation installation
./docker-compose.sh
}

function display_credentials()
{
info "=======> CISO ASSISTANT installation details  <======="
info "Default Accounts details:"
info "USER       -  PASSWORD       -  ACCESS"
info "admin       -  ChangeMe      -  admin account,"
echo ""
info "You can access to your ciso assistant instance from this links:"
info "http://$FQDN" 
echo ""
info "<==========================================>"
echo ""
}

function save_credentials()
{
{
info "=======> CISO ASSISTANT installation details  <======="
info "Default Accounts details:"
info "USER       -  PASSWORD       -  ACCESS"
info "admin       -  ChangeMe      -  admin account,"
echo ""
info "You can access to your ciso assistant instance from this links:"
info "http://$FQDN" 
echo ""
info "<==========================================>"
echo ""
} >> ~/cisoassistant.creds

msg_info "use : cat cisoassistant.creds to retreive all the credentials"
}

install_docker
install_ciso
display_credentials
save_credentials

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
