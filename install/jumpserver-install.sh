#!/usr/bin/env bash
# Copyright (c) 2021-2025 M3d1
# Author: m3di1 - Mehdi BASRI
# License: MIT
# https://github.com/m3d1/PVE-Scripts/raw/main/LICENSE

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

function warn(){
    echo -e '\e[31m'$1'\e[0m';
}

function check_root()
{
# Root Privilleges check
if [[ "$(id -u)" -ne 0 ]]
then
        warn "the script should be initiated with root privileges" >&2
  exit 1
else
        msg_ok "privilege Root: OK"
fi
}

function check_distro()
{
apt install lsb-release -y
# Allowed Distro Versions
VERSION=v4.6.0
DOWNLOAD_URL=https://github.com
DEBIAN_VERSIONS=("11" "12")
UBUNTU_VERSIONS=("22.04")
DISTRO=$(lsb_release -is)
VERSION=$(lsb_release -rs)


if [[ "${OS}" == 'Darwin' ]]; then
  echo
  echo "Unsupported Operating System Error"
  exit 1
fi

# Debian Distribution Check
if [ "$DISTRO" == "Debian" ]; then
        if [[ " ${DEBIAN_VERSIONS[*]} " == *" $VERSION "* ]]; then
                msg_info "the OS: $DISTRO $VERSION is compatible."
        else
                msg_error "This OS $DISTRO $VERSION is not compatible"
                msg_error "Would you like to force the installation?"
                msg_info "Would you like to continue? [y/N]"
                read response
                if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
                msg_info "Starting the Instalation"
                elif [[ "${prompt,,}" =~ ^(n|N|no|NO)$ ]]; then
                msg_info "Closing..."
                exit 1
                else
                msg_error "wrong Answer, Closing the setup"
                exit 1
                fi
        fi

# Ubuntu Distribution Check
elif [ "$DISTRO" == "Ubuntu" ]; then
        if [[ " ${UBUNTU_VERSIONS[*]} " == *" $VERSION "* ]]; then
                msg_info "the OS: $DISTRO $VERSION is compatible."
        else
                msg_error "This OS $DISTRO $VERSION is not compatible"
                msg_error "Would you like to force the installation?"
                msg_info "Would you like to continue? [y/N]"
                read response
                if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
                msg_info "Starting the Instalation"
                elif [[ "${prompt,,}" =~ ^(n|N|no|NO)$ ]]; then
                msg_info "Closing..."
                exit 1
                else
                msg_error "wrong Answer, Closing the setup"
                exit 1
                fi
        fi
else
        msg_error "the OS you are using is not compatible with this installation script."
        exit 1
fi
}

function network_info()
{
INTERFACE=$(ip route | awk 'NR==1 {print $5}')
IPADRESS=$(ip addr show $INTERFACE | grep inet | awk '{ print $2; }' | sed 's/\/.*$//' | head -n 1)
HOST=$(hostname)
}

#### JUMPSERVER SPECIFIC SCRIPTS #### 
function install_soft() {
    if command -v dnf &>/dev/null; then
      dnf -q -y install "$1"
    elif command -v yum &>/dev/null; then
      yum -q -y install "$1"
    elif command -v apt &>/dev/null; then
      apt-get -qqy install "$1"
    elif command -v zypper &>/dev/null; then
      zypper -q -n install "$1"
    elif command -v apk &>/dev/null; then
      apk add -q "$1"
      command -v gettext &>/dev/null || {
      apk add -q gettext-dev python3
    }
    else
      msg_error " $1 command not found, Please install it first"
      exit 1
    fi
}

function prepare_install() {
  for i in curl wget tar iptables; do
    command -v $i &>/dev/null || install_soft $i
  done
}

function get_installer() {
  msg_info "download install script to /opt/jumpserver-installer-${VERSION}"
  cd /opt || exit 1
  if [ ! -d "/opt/jumpserver-installer-${VERSION}" ]; then
    timeout 60 wget -qO jumpserver-installer-${VERSION}.tar.gz ${DOWNLOAD_URL}/jumpserver/installer/releases/download/${VERSION}/jumpserver-installer-${VERSION}.tar.gz || {
      rm -f /opt/jumpserver-installer-${VERSION}.tar.gz
      msg_error " Failed to download jumpserver-installer-${VERSION}"
      exit 1
    }
    tar -xf /opt/jumpserver-installer-${VERSION}.tar.gz -C /opt || {
      rm -rf /opt/jumpserver-installer-${VERSION}
      msg_error " Failed to unzip jumpserver-installer-${VERSION}"
      exit 1
    }
    rm -f /opt/jumpserver-installer-${VERSION}.tar.gz
  fi
}

function config_installer() {
  cd /opt/jumpserver-installer-${VERSION} || exit 1
  ./jmsctl.sh install
  ./jmsctl.sh start
}
#### JUMPSERVER SPECIFIC SCRIPTS #### 


function display_credentials()
{
info "=======> JUMPSERVER installation details  <======="
info "Default Accounts details:"
info "USER       -  PASSWORD       -  ACCESS"
info "admin       -  ChangeMe      -  admin account,"
echo ""
info "You can access to your jumpserver from this links:"
info "http://$IPADRESS or http://$HOST" 
echo ""
info "<==========================================>"
echo ""
}

function save_credentials()
{
{
info "=======> JUMPSERVER installation details  <======="
info "Default Accounts details:"
info "USER       -  PASSWORD       -  ACCESS"
info "admin       -  ChangeMe      -  admin account,"
echo ""
info "You can access to your jumpserver from this links:"
info "http://$IPADRESS or http://$HOST" 
echo ""
info "<==========================================>"
echo ""
} >> ~/jumpserver.creds

msg_info "use : cat jumpserver.creds to retreive all the credentials"
}

check_root
check_distro
network_info
  
prepare_install
get_installer
config_installer

display_credentials
save_credentials

motd_ssh
customize

msg_info "Cleaning up"
rm "/opt/v${RELEASE}.zip"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
