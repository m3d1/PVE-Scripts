#!/bin/bash
#!/usr/bin/env bash

# Copyright (c) 2024 M3d1
# Author: M3d1
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/MicrosoftDocs/sql-docs/blob/live/docs/linux/sample-unattended-install-ubuntu.md

################################################################################
# Script for installing Odoo on Ubuntu 22.04 LTS (could be used for other version too)
#-------------------------------------------------------------------------------
# This script will install Odoo on your Ubuntu 22.04 server. It can install multiple Odoo instances
# in one Ubuntu because of the different xmlrpc_ports
#-------------------------------------------------------------------------------
################################################################################

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  sudo \
  lsb-release \
  curl \
  gnupg \
  mc \
  software-properties-common
msg_ok "Installed Dependencies"

function m_warn(){
    echo -e '\e[33m'$1'\e[0m';
}


if [[ "$(id -u)" -ne 0 ]]
then
        msg_error "the script should be initiated with root privileges" >&2
  exit 1
else
        msg_ok "privilege Root: OK"
        msg_info "Script is running as root, so creating new odoo user"
fi


OD_USER="odoo"
OD_HOME="/opt/$OD_USER"
OD_VERSION="16.0"
INSTALL_WKHTMLTOPDF="True"
OD_INSTALL_DIR="/opt/$OD_USER/$OD_VERSION" #/opt/
OD_REPO="$OD_INSTALL_DIR/odoo"
INSTALL_PG_SERVER="True" # if false, than only client will be installed
OD_DB_HOST="localhost"
OD_DB_PORT="5432"
OD_DB_USER="odoo"
OD_DB_PASSWORD="odoo"
PG_VERSION=12
OD_NETRPC_PORT="8070"
OD_LONGPOOL_PORT="8072"
OD_WORKERS="4"
OD_PORT="8069"
IS_ENTERPRISE="False"
OD_SUPERADMIN=$(openssl rand -base64 48 | cut -c1-12 )
WEB_SERVER="nginx" 
HTTP_PROTOCOL="https"
HTTPS_PORT="443"
INTERFACE="eth0"
PUBLIC_IP=$(ip addr show $INTERFACE | grep inet | awk '{ print $2; }' | sed 's/\/.*$//' | head -n 1)
HOST=$(hostname)
DOMAIN_NAME="{$HOST}.local.host" #
DOMAIN_ALIASES=({$DOMAIN_NAME})
LE_EMAIL="support@local.host"
LE_CRON_SCRIPT="/etc/cron.daily/certbot-renew"
INSTALL_CERTIFICATE="FALSE"
CERTIFICATE_TYPE="SELF-SIGNED" # SELF-SEIGNED OR ACME
DHPARAM="True"
#--------------------------------------------------
# Server Params
#--------------------------------------------------


read -r -p "would you like to install other version than $OD_VERSION (y/N) :" prompt
if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
      read -r -p "type the version you want to deploy (example: 17.0) :" OD_VERSION
fi

#Set to true if you want to install it, false if you don't need it or have it already installed.

read -r -p "would you like to install WKHTMLTOPDF (Y/n) :" prompt
if [[ "${prompt,,}" =~ ^(n|no)$ ]]; then
      INSTALL_WKHTMLTOPDF="False"
fi

read -r -p "would you like to change the default port $OD_PORT (y/N) :" prompt
if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
      read -r -p "type the port :" OD_PORT
fi

read -r -p "would you like to change the default number of workers $OD_WORKERS (y/N) :" prompt
if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
      read -r -p "Enter the number of workers :" OD_WORKERS
fi

#set the superadmin password

read -r -p "would you like to set a personal superadmin password (y/N) :" prompt
if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
      read -r -p "Prompt your new Password :" OD_SUPERADMIN
fi

msg_info "\n---- Create ODOO system user ----"
adduser --system --quiet --shell=/bin/bash --home=$OD_HOME --gecos 'ODOO' --group $OD_USER
#The user should also be added to the sudo'ers group.
adduser $OD_USER sudo

read -r -p "would you like to skip the installation of PGSQL (y/N) :" prompt
if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
      INSTALL_PG_SERVER="false"
      read -r -p "Enter IP address of FQDN of the remote DB" OD_DB_HOST
else
  read -r -p "would you like to install PGSQL 14 (y/N) :" prompt
  if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
      PG_VERSION=14
  fi
  msg_info "PGSQL version $PG_VERSION will be deployed"
fi

read -r -p "would you like to set a personal superadmin password (y/N) :" prompt
if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
      read -r -p "Prompt your new Password :" OD_SUPERADMIN
fi

read -r -p "Provide a domain name :" DOMAIN_NAME
m_warn "Make sure to configure your dns records !!"
read -r -p "would you like to add domain alias(es) (y/N) :" prompt
if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
      read -r -p "prompt your domain alias(es) separated by a "space" :" DOMAIN_ALIASES
fi

read -r -p "would you like to install a web certificate (y/N) :" prompt
if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
      INSTALL_CERTIFICATE="True"
      read -r -p "would you like to a self-signed certificate (Y) or Let's Encrypt Certificate (n) :" prompt
      if [[ "${prompt,,}" =~ ^(n|no)$ ]]; then
      read -r -p "would you like to a self-signed certificate (Y) or Let's Encrypt Certificate (n) :" prompt
      CERTIFICATE_TYPE="ACME"
      m_warn "make sure your domain is recheable from Internet !"
      fi
      msg_info " $CERTIFICATE_TYPE will be installed for this instance"
fi

if [ $IS_ENTERPRISE = "True" ]; then
    OD_CONFIG="$OD_INSTALL_DIR/odoo-enterprise.conf"
    OD_INIT="odoo-$OD_VERSION-enterprise"
    OD_WEBSERV_CONF="odoo-$OD_VERSION-enterprise.conf"
    OD_WEBSERVER_HOST="odoo$OD_VERSION-e"
    OD_ADDONS_PATH="$OD_INSTALL_DIR/odoo-custom-addons,$OD_INSTALL_DIR/enterprise/addons,$OD_REPO/addons"
    OD_LOG_PATH="$OD_INSTALL_DIR/logs/enterprise"
    OD_TEXT="Enterprise"
else
    OD_CONFIG="/etc/odoo-$OD_VERSION.conf"
	OD_INIT_CONFIG="odoo-$OD_VERSION.service"
    OD_INIT="odoo-$OD_VERSION"
    OD_WEBSERV_CONF="odoo-$OD_VERSION.conf"
    OD_WEBSERVER_HOST="odoo$OD_VERSION"
    OD_ADDONS_PATH="$OD_INSTALL_DIR/odoo-custom-addons,$OD_REPO/addons"
    OD_LOG_PATH="$OD_INSTALL_DIR/logs/community"
    OD_TEXT="Community"
fi

if [ $OD_VERSION = "11.0" ] || [ $OD_VERSION = "12.0" ] || [ $OD_VERSION = "13.0" ] || [ $OD_VERSION = "14.0" ] || [ $OD_VERSION = "15.0" ] || [ $OD_VERSION = "16.0" ] || [ $OD_VERSION = "17.0" ] || [ $OD_VERSION = "18.0" ]; then
    PYTHON_VERSION="3"
else
    PYTHON_VERSION="2"
fi
#--------------------------------------------------
# Update Server
#--------------------------------------------------
msg_info "\n---- Update Server ----"
$STD apt-get update
$STD apt-get upgrade -y
$STD apt-get install git wget build-essential dnsutils lsb-release libssl-dev libxslt-dev libgd-dev curl nano gnupg2 ca-certificates software-properties-common sudo -y
#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
PG_ALREADY_INSTALLED="False"
# Let's  first check if postgres already installed
if [ $INSTALL_PG_SERVER = "True" ]; then
    SERVER_RESULT=`sudo -E -u postgres bash -c "psql -X -p $OD_DB_PORT -c \"SELECT version();\""`
    if [ -z "$SERVER_RESULT" ]; then
        msg_info "No postgres database is installed on port $OD_DB_PORT. So we will install it."
    else
        if [[ $SERVER_RESULT == *"PostgreSQL $PG_VERSION"* ]]; then
            msg_ok "We already have PostgreSQL Server $PG_VERSION installed and running port $OD_DB_PORT. Skipping it's installation."
            PG_ALREADY_INSTALLED="True"
        else
            msg_error "Version other than PostgreSQL $PG_VERSION Server installed on port $OD_DB_PORT. Make sure that you have configured port correctly. Aborting!"
            exit 1
        fi
    fi
else
    CLIENT_RESULT=`psql -V`
    if [ -z "$CLIENT_RESULT" ]; then
        msg_info "No PosgreSQL Client installed. Installing it."
    else
        if [[ $CLIENT_RESULT == *"$PG_VERSION"* ]]; then
            msg_info "We already have PostgreSQL Client version $PG_VERSION. Skipping installation."
            PG_ALREADY_INSTALLED="True"
        else
            m_warn "Not correct version of PostgreSQL Client installed. Required $PG_VERSION, installed '$CLIENT_RESULT'. We will try to reinstall again."
        fi
    fi
fi

msg_info "\n---- Install PostgreSQL Server ----"
if [ $PG_ALREADY_INSTALLED == "False" ]; then
    $STD apt-get install software-properties-common -y
    $STD sudo curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc|sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
    $STD sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    #sudo add-apt-repository "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -sc)-pgdg main" -y                                 #05/12/2024
    #wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    $STD apt-get update -y
fi

if [ $INSTALL_PG_SERVER = "True" ]; then
    export PG_CONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
    export PG_HBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
    if [ $PG_ALREADY_INSTALLED == "False" ]; then
        msg_info "\n---- Install PostgreSQL Server ----"
        $STD apt-get install postgresql-$PG_VERSION -y
        # Edit postgresql.conf to change listen address to '*':
        $STD sudo -u postgres sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONF"
        # Edit postgresql.conf to change port to '$OD_DB_PORT':
        $STD sudo -u postgres sed -i "s/port = 5432/port = $OD_DB_PORT/" "$PG_CONF"
    fi
    # Even if PostgresSQL Server is already installed, we may still want to optimize it for ERP and create DB user.
    export MEM=$(awk '/^MemTotal/ {print $2}' /proc/meminfo)
    export CPU=$(awk '/^processor/ {print $3}' /proc/cpuinfo | wc -l)
    export CONNECTIONS="100"
    # Explicitly set default client_encoding
    $STD sudo -E -u postgres bash -c 'echo "client_encoding = utf8" >> "$PG_CONF"'
    # Explicitly set parameters for ERP/OLTP
    $STD sudo -E -u postgres bash -c 'echo "effective_cache_size = $(( $MEM * 3 / 4 ))kB" >> "$PG_CONF"'
    $STD sudo -E -u postgres bash -c 'echo "checkpoint_completion_target = 0.9" >> "$PG_CONF"'
    $STD sudo -E -u postgres bash -c 'echo "shared_buffers = $(( $MEM / 4 ))kB" >> "$PG_CONF"'
    $STD sudo -E -u postgres bash -c 'echo "maintenance_work_mem = $(( $MEM / 16 ))kB" >> "$PG_CONF"'
    $STD sudo -E -u postgres bash -c 'echo "work_mem = $(( ($MEM - $MEM / 4) / ($CONNECTIONS * 3) ))kB" >> "$PG_CONF"'
    $STD sudo -E -u postgres bash -c 'echo "random_page_cost = 4         # or 1.1 for SSD" >> "$PG_CONF"'
    $STD sudo -E -u postgres bash -c 'echo "effective_io_concurrency = 2 # or 200 for SSD" >> "$PG_CONF"'
    $STD sudo -E -u postgres bash -c 'echo "max_connections = $CONNECTIONS" >> "$PG_CONF"'
    # Now let's create new user
    export OD_DB_USER
    export OD_DB_PASSWORD
    # Append to pg_hba.conf to add password auth:
    $STD sudo -E -u postgres bash -c 'echo "host    all             $OD_DB_USER             all                     md5" >> "$PG_HBA"'
    # Restart so that all new config is loaded:
    $STD sudo service postgresql restart
    msg_info "\n---- Creating the ODOO PostgreSQL User  ----"
    $STD sudo -E -u postgres bash -c "psql -X -p $OD_DB_PORT -c \"CREATE USER $OD_DB_USER WITH CREATEDB NOCREATEROLE NOSUPERUSER PASSWORD '$OD_DB_PASSWORD';\""
    # Restart so that all new config is loaded:
    sudo service postgresql restart
else
    msg_info "\n---- Install PostgreSQL Client ----"
    $STD apt-get install postgresql-client-$PG_VERSION -y
fi
#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
if [ $OD_VERSION = "10.0" ] || [ $OD_VERSION = "11.0" ] || [ $OD_VERSION = "12.0" ] || [ $OD_VERSION = "13.0" ] || [ $OD_VERSION = "14.0" ] || [ $OD_VERSION = "15.0" ] || [ $OD_VERSION = "16.0" ] || [ $OD_VERSION = "17.0" ] || [ $OD_VERSION = "18.0" ]; then
    OD_BIN="odoo-bin"
else
    OD_BIN="openerp-server"
fi

msg_info "\n---- Python Dependencies ----"

if [ $PYTHON_VERSION = "3" ]; then
#----------------- Python 3 ------------------
    if [ $(which python3.6) ] || [ $(which python3.7) ] || [ $(which python3.8) ] || [ $(which python3.9) ] || [ $(which python3.10) ] || [ $(which python3.11) ] || [ $(which python3.12) ]; then
        $STD apt-get install python3 python3-pip -y
        $STD apt-get install git python3-cffi build-essential wget python3-dev python3-venv python3-wheel libxslt-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools node-less libpng-dev libjpeg-dev gdebi -y
    else
        msg_error "System has wrong python version! Odoo supports only 3.6+ python"
        exit 1
    fi
else
#------------------ Python 2 -------------------
    $STD apt-get install -y python-dev python-virtualenv python-setuptools python-pip
fi

msg_info "\n---- Odoo Web Dependencies ----"
$STD apt-get install -y nodejs npm
$STD apt-get install -y node-less node-clean-css
$STD sudo npm install -g less less-plugin-clean-css

#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------
INSTALL_WKHTMLTOPDF_VERSION='wkhtmltopdf --version'
if [ $INSTALL_WKHTMLTOPDF = "True" ] && [ -z "$INSTALL_WKHTMLTOPDF_VERSION" ]; then
  msg_info "\n---- Install wkhtml and place shortcuts on correct place for ODOO $OD_VERSION ----"

  OS_RELEASE=`lsb_release -sc`
  if [ "`getconf LONG_BIT`" == "64" ];then
      #_url=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1."$OS_RELEASE"_amd64.deb
	  _url=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.$OS_RELEASE_amd64.deb
  else
      #_url=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1."$OS_RELEASE"_i386.deb
	  _url=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.$OS_RELEASE_i386.deb
  fi
  wget $_url
  $STD sudo dpkg -i `basename $_url`
  $STD apt-get install -f -y
else
  msg_info "Wkhtmltopdf isn't installed due to the choice of the user!"
fi  
msg_info "\n---- Create Log directory ----"
mkdir -p $OD_LOG_PATH
#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
if [ ! -d "$OD_REPO" ]; then
    msg_info "\n==== Installing ODOO Server ===="
    git clone --depth 1 --branch $OD_VERSION https://www.github.com/odoo/odoo $OD_REPO/
fi
if [ ! -d "$OD_INSTALL_DIR/odoo-venv" ]; then
    msg_info "* Create virtualenv"
    if [ $PYTHON_VERSION = "3" ]; then
        python3 -m venv $OD_INSTALL_DIR/odoo-venv
    else
        virtualenv $OD_INSTALL_DIR/odoo-venv
    fi
fi

source $OD_INSTALL_DIR/odoo-venv/bin/activate
$STD apt-get install libicu-dev libpq-dev libxml2-dev libxslt1-dev libsasl2-dev libldap2-dev libssl-dev zlib1g-dev -y
pip install --upgrade pip
pip install wheel

if [[ -f $OD_REPO/requirements.txt ]]; then
    msg_info "Installing from $OD_REPO/requirements.txt with pip."
    if [ $PYTHON_VERSION = "3" ]; then
        pip3 install -r $OD_REPO/requirements.txt
    else
        pip install -r $OD_REPO/requirements.txt
    fi
fi

if [ $IS_ENTERPRISE = "True" ]; then
    if [ ! -d "$OD_INSTALL_DIR/enterprise/addons" ]; then
        # Odoo Enterprise install!
        mkdir -p $OD_INSTALL_DIR/enterprise/addons

        msg_info "\n---- Adding Enterprise code under $OD_HOME/enterprise/addons ----"
        git clone --depth 1 --branch $OD_VERSION https://www.github.com/odoo/enterprise "$OD_INSTALL_DIR/enterprise/addons"
    fi
fi
if [ ! -d "$OD_INSTALL_DIR/odoo-custom-addons" ]; then
    msg_info "\n---- Create custom module directory ----"
    mkdir -p $OD_INSTALL_DIR/odoo-custom-addons
fi

if [ ! -f "$OD_CONFIG" ]; then
    msg_info "* Create server config file"

cat <<EOF > $OD_CONFIG
[options]
admin_passwd = $OD_SUPERADMIN
db_host = $OD_DB_HOST
db_port = $OD_DB_PORT
db_user = $OD_DB_USER
db_password = $OD_DB_PASSWORD
addons_path = $OD_ADDONS_PATH
data_dir = $OD_HOME/.local/share/odoo$OD_VERSION
log_level = info
logfile = $OD_LOG_PATH/odoo-server.log
syslog = False
log_handler = ["[':INFO']"]
xmlrpc = True
xmlrpc_interface = 127.0.0.1
xmlrpc_port = $OD_PORT
netrpc = True
netrpc_interface = 127.0.0.1
netrpc_port = $OD_NETRPC_PORT
longpolling_port = $OD_LONGPOOL_PORT
workers = $OD_WORKERS
limit_time_cpu = 1200
limit_time_real = 1200
limit_request = 1200
proxy_mode = True
EOF

fi

if [[ $EUID -eq 0 ]]; then
   msg_info "\n---- Setting permissions on home folder as we are executing script as a root----"
   chown -R $OD_USER:$OD_USER $OD_HOME
fi

#--------------------------------------------------
# ----- Creating debian installation file with all neccessary configs
#--------------------------------------------------

OD_AUTO_SCRIPTS_DIR=$OD_HOME/odoo_install_$OD_VERSION
mkdir $OD_AUTO_SCRIPTS_DIR

msg_info "creating temporary folders"
echo -e $OD_AUTO_SCRIPTS_DIR/etc/init.d/
mkdir -p $OD_AUTO_SCRIPTS_DIR/etc/init.d/

echo -e $OD_AUTO_SCRIPTS_DIR/etc/systemd/system/
mkdir -p $OD_AUTO_SCRIPTS_DIR/etc/systemd/system/

# ---------------------------
# Build Debian package
# ---------------------------
mkdir -p $OD_AUTO_SCRIPTS_DIR/DEBIAN
cd $OD_AUTO_SCRIPTS_DIR/DEBIAN

cat <<EOF > $OD_AUTO_SCRIPTS_DIR/DEBIAN/control
Package: $OD_INIT
Version: $OD_PORT
Architecture: all
Maintainer: Odoo S.A. <info@odoo.com>
Section: net
Priority: optional
Homepage: http://www.odoo.com/
Description: Odoo description
EOF

cat <<EOF > $OD_AUTO_SCRIPTS_DIR/DEBIAN/postinst
#!/bin/sh

set -e

ODOO_CONFIGURATION_FILE=$OD_CONFIG
ODOO_GROUP=$OD_USER
ODOO_DATA_DIR=$OD_HOME
ODOO_LOG_DIR=$OD_LOG_PATH
ODOO_USER=$OD_USER

# Configuration file
chown \$ODOO_USER:\$ODOO_GROUP \$ODOO_CONFIGURATION_FILE
chmod 0640 \$ODOO_CONFIGURATION_FILE
# Log
chown \$ODOO_USER:\$ODOO_GROUP \$ODOO_LOG_DIR
chmod 0750 \$ODOO_LOG_DIR
# Data dir
chown \$ODOO_USER:\$ODOO_GROUP \$ODOO_DATA_DIR
# Different scripts
chown root:root /etc/init.d/$OD_INIT
chmod 755 /etc/init.d/$OD_INIT

update-rc.d $OD_INIT defaults

EOF

chmod 755 $OD_AUTO_SCRIPTS_DIR/DEBIAN/postinst

#--------------------------------------------------
# Adding init.d script
#--------------------------------------------------
cd $OD_AUTO_SCRIPTS_DIR/etc/init.d/

msg_info "* Create init file"
cat <<EOF > $OD_AUTO_SCRIPTS_DIR/etc/init.d/$OD_INIT
#!/bin/sh
### BEGIN INIT INFO
# Provides: $OD_INIT
# Required-Start: \$remote_fs \$syslog
# Required-Stop: \$remote_fs \$syslog
# Should-Start: \$network
# Should-Stop: \$network
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Start odoo daemon at boot time
# Description:       Enable service provided by daemon.
# X-Interactive:     true
### END INIT INFO
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin
VIRTENV=$OD_INSTALL_DIR/env/bin/python
DAEMON=$OD_REPO/$OD_BIN
NAME=$OD_INIT
DESC=$OD_INIT
# Specify the user name (Default: odoo).
USER=$OD_USER
CONFIGFILE="${OD_CONFIG}"
# pidfile
PIDFILE=/var/run/\${NAME}.pid
# Additional options that are passed to the Daemon.
DAEMON_OPTS="-c \$CONFIGFILE"
[ -x \$DAEMON ] || exit 0
[ -f \$CONFIGFILE ] || exit 0
checkpid() {
[ -f \$PIDFILE ] || return 1
pid=\`cat \$PIDFILE\`
[ -d /proc/\$pid ] && return 0
return 1
}
case "\${1}" in
start)
echo -n "Starting \${DESC}: "
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$VIRTENV \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
stop)
echo -n "Stopping \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
echo "\${NAME}."
;;
restart|force-reload)
echo -n "Restarting \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
sleep 10
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$VIRTENV \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
*)
N=/etc/init.d/\$NAME
echo "Usage: \$NAME {start|stop|restart|force-reload}" >&2
exit 1
;;
esac
exit 0
EOF

msg_info "* Security Init File"
$STD sudo mkdir -p $OD_AUTO_SCRIPTS_DIR/etc/init.d/
msg_info "*Copy Security Init File to init.d folder"
$STD sudo cp $OD_AUTO_SCRIPTS_DIR/etc/init.d/$OD_INIT /etc/init.d/

#--------------------------------------------------
# Adding systemd script
#--------------------------------------------------
msg_info "* Create Systemd file"
cat <<EOF > $OD_AUTO_SCRIPTS_DIR/etc/systemd/system/$OD_INIT_CONFIG
[Unit]
Description=odoo-$OD_VERSION
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo
PermissionsStartOnly=true
User=odoo
Group=odoo
ExecStart=/opt/odoo/$OD_VERSION/odoo-venv/bin/python3 /opt/odoo/$OD_VERSION/odoo/odoo-bin -c /etc/odoo-$OD_VERSION.conf
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

msg_info "* Copy initd file to systemd,reload daemon then enable odoo"
$STD sudo cp $OD_AUTO_SCRIPTS_DIR/etc/systemd/system/$OD_INIT_CONFIG /etc/systemd/system/$OD_INIT_CONFIG
$STD sudo systemctl daemon-reload
$STD sudo systemctl enable --now odoo-$OD_VERSION.service


# -------------------------------
# INSTALL WEBSERVER SECTION
# -------------------------------
# ---------------------------------------------------
# NGINX RELATED SECTION
# --------------------------------------------------
$STD sudo add-apt-repository ppa:ondrej/nginx-mainline -y
$STD apt update -y
echo -e "* Install nginx"
$STD apt-get install nginx nginx-core nginx-common nginx-full -y

# ---------------------------------------------------
# SSL SECTION SECTION
# ---------------------------------------------------
VAR_DHPARAM=""
VAR_SSLKEY=""
VAR_SSLCRT=""


if [ $INSTALL_CERTIFICATE == "True" ] && [ $CERTIFICATE_TYPE == "ACME" ] && [ ! -z "$DOMAIN_NAME" ];then
  $STD apt-get install dnsutils dirmngr git wget

  # Check if domain is reachable
    PUBLIC_IP=`dig +short myip.opendns.com @resolver1.opendns.com`
    REACHED_IP=`dig $DOMAIN_NAME A +short`
    if [[ $REACHED_IP == $PUBLIC_IP ]]; then
        INSTALL_CERTIFICATE="True"
    else
        INSTALL_CERTIFICATE="False"
        m_warn "IMPORTANT! Skipping certificate installation, as it is not possible to resolve domain ${DOMAIN_NAME} to IP ${PUBLIC_IP}"
    fi

    if [ $INSTALL_CERTIFICATE = "True" ]; then
        $STD sudo add-apt-repository "deb http://ftp.debian.org/debian $(lsb_release -sc)-backports main"
        $STD apt-get update
        domains="-d $DOMAIN_NAME"
        for alias in ${DOMAIN_ALIASES[@]} ; do
            domains="$domains -d $alias"
        done
        if [ $WEB_SERVER = "nginx" ] ; then
            echo -e "Configuring certificate with Nginx"
            $STD apt-get install python-certbot-nginx -y
            sudo certbot --nginx $domains --non-interactive --agree-tos --redirect -m $LE_EMAIL
        fi
    fi
fi

if [ $INSTALL_CERTIFICATE == "True" ] && [ $CERTIFICATE_TYPE == "SELF-SIGNED" ];then
 $STD apt-get install openssl -y
 $STD sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/nginx-odoo$OD_VERSION-selfsigned.key -out /etc/ssl/certs/nginx-odoo$OD_VERSION-selfsigned.crt
 VAR_SSLCRT="/etc/ssl/private/nginx-odoo$OD_VERSION-selfsigned.key"
 VAR_SSLKEY="/etc/ssl/certs/nginx-odoo$OD_VERSION-selfsigned.crt"

 m_warn "WARNING : installing a 4096 dhparm can take some time , be patient !! or skip this task"
 read -r -p "would you to generate a 4096 dhparam key?  <y/N> ?" prompt
 if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
      DHPARAM="True"
      openssl dhparam -out /etc/nginx/dhparam.pem 4096
      VAR_DHPARAM="ssl_dhparam /etc/nginx/dhparam.pem;"
 fi
fi


msg_info "Configuring Odoo with Nginx"
domains="$DOMAIN_NAME"
for alias in ${DOMAIN_ALIASES[@]} ; do
    domains="$domains $alias"
done

if [ $INSTALL_CERTIFICATE == "FALSE" ]; then
cat <<EOF > $OD_WEBSERV_CONF
# odoo server
upstream $OD_WEBSERVER_HOST {
 server 127.0.0.1:$OD_PORT;
}
upstream chat_$OD_WEBSERVER_HOST {
 server 127.0.0.1:$OD_LONGPOOL_PORT;
}

server {
 server_name $domains;
 listen 80;

 proxy_read_timeout 720s;
 proxy_connect_timeout 720s;
 proxy_send_timeout 720s;

 # Add Headers for odoo proxy mode
 proxy_set_header X-Forwarded-Host \$host;
 proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
 proxy_set_header X-Forwarded-Proto \$scheme;
 proxy_set_header X-Real-IP \$remote_addr;

 # log
 access_log /var/log/nginx/$OD_INIT.access.log;
 error_log /var/log/nginx/$OD_INIT.error.log;

 # Redirect requests to odoo backend server
 location / {
   proxy_redirect off;
   proxy_pass http://$OD_WEBSERVER_HOST;
 }
 location /longpolling {
     proxy_pass http://chat_$OD_WEBSERVER_HOST;
 }

 # Specifies the maximum accepted body size of a client request,
 # as indicated by the request header Content-Length.
 client_max_body_size 200m;

 # common gzip
 gzip_types text/css text/less text/plain text/xml application/xml application/json application/javascript;
 gzip on;
}
EOF

else

cat <<EOF > /etc/nginx/snippets/self-$DOMAIN_NAME.conf
$VAR_SSLCRT
$VAR_SSLKEY
EOF

cat <<EOF > /etc/nginx/snippets/ssl-params.conf
ssl_protocols TLSv1.2; 
ssl_prefer_server_ciphers on; 
$VAR_DHPARAM
ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512: DHE-RSA-AES256-GCM-SHA512: ECDHE-RSA-AES256-GCM-SHA384: DHE-RSA-AES256-GCM-SHA384: ECDHE-RSA-A38256; 

ssl_ecdh_curve secp384r1; 
sssl_session_timeout 1d;
ssl_session_cache shared:SSL:50m;
ssl_session_tickets off;

ssl_stapling on; 
ssl_stapling_verify on; 

resolver 8.8.8.8 8.8.4.4 valid = 300s; 
resolver_timeout 5s; 

# add_header Strict-Transport-Security "max-age = 63072000; includeSubDomains; preload"; 
# add_header Strict-Transport-Security max-age=15768000;
add_header X-Frame-Options DENY; 
add_header X-Content-Type-Options nosniff; 
add_header X-XSS-Protection "1; mode = block";
EOF

cat <<EOF > $OD_WEBSERV_CONF
# odoo server
upstream $OD_WEBSERVER_HOST {
 server 127.0.0.1:$OD_PORT;
}
upstream chat_$OD_WEBSERVER_HOST {
 server 127.0.0.1:$OD_LONGPOOL_PORT;
}
server {
    server_name $domains;
    return 301 https://odoo.example.com$request_uri;
}
server {
   listen 443 ssl http2;
   server_name $domains;

   include snippets / self-$DOMAIN_NAME.conf; 
   include snippets / ssl-params.conf; 
   
   # log
   access_log /var/log/nginx/$OD_INIT.access.log;
   error_log /var/log/nginx/$OD_INIT.error.log;

   proxy_read_timeout 720s;
   proxy_connect_timeout 720s;
   proxy_send_timeout 720s;
   proxy_set_header X-Forwarded-Host $host;
   proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
   proxy_set_header X-Forwarded-Proto $scheme;
   proxy_set_header X-Real-IP $remote_addr;

   # Redirect requests to odoo backend server
   location / {
      proxy_redirect off;
      proxy_pass http://$OD_WEBSERVER_HOST;
    }
    location /longpolling {
     proxy_pass http://chat_$OD_WEBSERVER_HOST;
    }

   location ~* /web/static/ {
       proxy_cache_valid 200 90m;
       proxy_buffering    on;
       expires 864000;
       proxy_pass http://$OD_WEBSERVER_HOST;
  }

  # gzip
  gzip_types text/css text/less text/plain text/xml application/xml application/json application/javascript;
  gzip on;
}
EOF

fi

mkdir -p $OD_AUTO_SCRIPTS_DIR/etc/nginx/sites-enabled/
#mv $OD_WEBSERV_CONF $OD_AUTO_SCRIPTS_DIR/etc/nginx/sites-enabled/
mv $OD_WEBSERV_CONF /etc/nginx/sites-enabled/

dpkg -b $OD_HOME/odoo_install_$OD_VERSION
$STDsudo dpkg -i $OD_HOME/odoo_install_$OD_VERSION.deb
# ------------------------------------------------------
# Logrotate Installation & Configutation section
# ------------------------------------------------------
msg_info "Install logrotate"
$STD apt-get install -y logrotate

cat <<EOF > /etc/logrotate.d/odoo
#Path odoo logs
   $OD_LOG_PATH/*.log {
        rotate 5
        size 100M
        daily
        compress
        delaycompress
        missingok
        notifempty
        su odoo odoo
}
EOF

# ----------------------------------------------------
# We are done! Let's start Odoo service
# ----------------------------------------------------
msg_info "* Starting Odoo Service"
$STD sudo service $OD_INIT start

cat <<OEF > /odoo.creds
echo "-----------------------------------------------------------"
echo "Done! The Odoo server is up and running. Specifications:"
echo "Odoo System User Name: $OD_USER"
echo "Odoo System User Home Directory: $OD_HOME"
echo "Odoo Installation Directory: $OD_INSTALL_DIR"
echo "Odoo Python virtual environment (for python libraries): $OD_INSTALL_DIR/env"
echo "Odoo Configuration File: $OD_CONFIG"
echo "Odoo Logs: $OD_LOG_PATH/odoo-server.log"
echo "Odoo Master Password: $OD_SUPERADMIN"
if [ $WEB_SERVER = "nginx" ]; then
    echo "Nginx Odoo Site: /etc/nginx/sites-available/$OD_WEBSERV_CONF"
fi
if [ $WEB_SERVER = "apache2" ]; then
    echo "Apache Odoo Site: /etc/apache2/sites-available/$OD_WEBSERV_CONF"
fi
if [ $HTTP_PROTOCOL = "https" ] || [ $INSTALL_CERTIFICATE = "True" ]; then
    echo "SSL Certificate File: $SSL_CERTIFICATE"
    echo "SSL Certificate Key File $SSL_CERTIFICATE_KEY"
fi
echo "Protocol: $HTTP_PROTOCOL"
echo "PostgreSQL version: $PG_VERSION"
echo "PostgreSQL User: $OD_DB_USER"
echo "PostgreSQL Password: $OD_DB_PASSWORD"
echo "Start Odoo service: sudo service $OD_INIT start"
echo "Stop Odoo service: sudo service $OD_INIT stop"
echo "Restart Odoo service: sudo service $OD_INIT restart"
echo "-----------------------------------------------------------"
OEF

echo "-----------------------------------------------------------"
echo "Done! The Odoo server is up and running. Specifications:"
echo "Odoo System User Name: $OD_USER"
echo "Odoo System User Home Directory: $OD_HOME"
echo "Odoo Installation Directory: $OD_INSTALL_DIR"
echo "Odoo Python virtual environment (for python libraries): $OD_INSTALL_DIR/env"
echo "Odoo Configuration File: $OD_CONFIG"
echo "Odoo Logs: $OD_LOG_PATH/odoo-server.log"
echo "Odoo Master Password: $OD_SUPERADMIN"
if [ $WEB_SERVER = "nginx" ]; then
    echo "Nginx Odoo Site: /etc/nginx/sites-available/$OD_WEBSERV_CONF"
fi
if [ $WEB_SERVER = "apache2" ]; then
    echo "Apache Odoo Site: /etc/apache2/sites-available/$OD_WEBSERV_CONF"
fi
if [ $HTTP_PROTOCOL = "https" ] || [ $INSTALL_CERTIFICATE = "True" ]; then
    echo "SSL Certificate File: $SSL_CERTIFICATE"
    echo "SSL Certificate Key File $SSL_CERTIFICATE_KEY"
fi
echo "Protocol: $HTTP_PROTOCOL"
echo "PostgreSQL version: $PG_VERSION"
echo "PostgreSQL User: $OD_DB_USER"
echo "PostgreSQL Password: $OD_DB_PASSWORD"
echo "Start Odoo service: sudo service $OD_INIT start"
echo "Stop Odoo service: sudo service $OD_INIT stop"
echo "Restart Odoo service: sudo service $OD_INIT restart"
echo "-----------------------------------------------------------"