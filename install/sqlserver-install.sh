#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/m3d1/PVE-Scripts/refs/heads/main/misc/build.func)
# Copyright (c) 2024 M3d1
# Author: M3d1
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/MicrosoftDocs/sql-docs/blob/live/docs/linux/sample-unattended-install-ubuntu.md

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

#repo list source for microsoft sql server
VERSION=$(grep "^VERSION_ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
#VERSION=$(awk -F= '$1=="VERSION_ID" { print $2 ;}' /etc/os-release)

MSREPO_LIST="mssql-server-2022"
if [[ "${VERSION}" == "20.04" ]]; then
      MSREPO_LIST='mssql-server-2019'
fi
if [[ "${VERSION}" == "24.04" ]]; then
      msg_error "MSSQL IS NOT SUPPORTED IN UBUNTU ${VERSION} USE 22.04 FOR YOUR PRODUCTION DEPLOYEMENT"
      msg_info "adding missing dependencies to the system ...."
      curl -OL http://archive.ubuntu.com/ubuntu/pool/main/o/openldap/libldap-2.5-0_2.5.18+dfsg-0ubuntu0.22.04.1_amd64.deb
      $STD apt-get install ./libldap-2.5-0_2.5.18+dfsg-0ubuntu0.22.04.1_amd64.deb
      VERSION="22.04"
      MSREPO_LIST="mssql-server-2022"
      msg_info "using repo for ${VERSION} instead of 24.04"
 else
       read -r -p "Would you like to use mssql-server-preview.list ? <y/N>" prompt
       if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
       MSREPO_LIST="mssql-server-preview"
       fi
fi
 msg_info "using the following repo ${MSREPO_LIST} "


MSSQL_SA_PASSWORD="P@ssw0rd!"
# Password for the SA user (required)
read -r -p "Would you to change default SA password (Note:Default password is: ${MSSQL_SA_PASSWORD})? <y/N> " prompt
if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
      read -r -p "Type your password :" MSSQL_SA_PASSWORD
fi


# Product ID of the version of SQL Server you're installing
# Must be evaluation, developer, express, web, standard, enterprise, or your 25 digit product key
MSSQL_PID='Developer'
#read -r -p "Type the edition of sql server you want to install (ex: Developer) or the 25 digit of your product key : " MSSQL_PID


# Enable SQL Server Agent (recommended)
SQL_ENABLE_AGENT="y"
read -r -p "Would to Disable SQL Server Agent (not recommended)? <y/N> " prompt
if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
      SQL_ENABLE_AGENT="n"
      msg_ok "SQL Server Agent Disabled"
fi


# Install SQL Server Full Text Search (optional)
SQL_INSTALL_FULLTEXT="n"
read -r -p "Would to Install SQL Server Full Text Search (optional)? <y/N> " prompt
if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
      SQL_INSTALL_FULLTEXT="n"
      msg_ok "SQL Server Full Text Search will not be installed"
else
      msg_ok "SQL Server Full Text Search will not be installed"
fi

# Create an additional user with sysadmin privileges (optional)
New_SYSADMIN="n"
read -r -p "Would you like to create additional user with sysadmin privileges (optional)? <y/N> " prompt
if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
      read -r -p "Enter username : " SQL_INSTALL_USER
      read -r -p "Enter username : " SQL_INSTALL_USER_PASSWORD
      New_SYSADMIN="y"
fi


msg_info "Adding Microsoft repositories..."
curl https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc
echo " adding new repo : https://packages.microsoft.com/config/ubuntu/${VERSION}/${MSREPO_LIST}.list)"
echo " adding new repo : https://packages.microsoft.com/config/ubuntu/${VERSION}/prod.list"
sleep 5
repoargs="$(curl https://packages.microsoft.com/config/ubuntu/${VERSION}/${MSREPO_LIST}.list)"
add-apt-repository "${repoargs}" -y
repoargs="$(curl https://packages.microsoft.com/config/ubuntu/${VERSION}/prod.list)"
add-apt-repository "${repoargs}" -y
sudo apt-get update -y
msg_ok "Microsoft repo added"

msg_info "Installing Microsoft SQL Server"
sudo apt-get install -y mssql-server
msg_info "Configuring Microsoft SQL Server"
msg_info "Running mssql-conf setup..."
sudo MSSQL_SA_PASSWORD=$MSSQL_SA_PASSWORD \
     MSSQL_PID=$MSSQL_PID \
     /opt/mssql/bin/mssql-conf -n setup accept-eula
msg_info "Installing mssql-tools and unixODBC developer..."
sudo ACCEPT_EULA=Y apt-get install -y mssql-tools unixodbc-dev
msg_info "Adding SQL Server tools to your path..."
echo PATH="$PATH:/opt/mssql-tools/bin" >> ~/.bash_profile
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
source ~/.bashrc


if [[ "${SQL_ENABLE_AGENT}" == "y" ]]; then
msg_info "Enabling SQL Server Agent..."
sudo /opt/mssql/bin/mssql-conf set sqlagent.enabled true
fi

# Optional SQL Server Full Text Search installation:
if [[ "${SQL_INSTALL_FULLTEXT}" == "y" ]]; then
    msg_info "Installing SQL Server Full-Text Search..."
    $STD apt-get install -y mssql-server-fts
fi

# Configure firewall to allow TCP port 1433:
#echo "Configuring UFW to allow traffic on port 1433..."
#sudo ufw allow 1433/tcp
#sudo ufw reload

msg_info "Restarting SQL Server..."
$STD systemctl restart mssql-server

# Connect to server and get the version:
counter=1
errstatus=1
while [ $counter -le 5 ] && [ $errstatus = 1 ]
do
  msg_info Waiting for SQL Server to start...
  sleep 3s
  /opt/mssql-tools/bin/sqlcmd \
    -S localhost \
    -U sa \
    -P $MSSQL_SA_PASSWORD \
    -Q "SELECT @@VERSION" 2>/dev/null
  errstatus=$?
  ((counter++))
done

# Display error if connection failed:
if [ $errstatus = 1 ]
then
  msg_error "Cannot connect to SQL Server, installation aborted"
  exit $errstatus
fi

# Optional new user creation:
if [[ "${New_SYSADMIN}" == "y" ]]; then
  echo Creating user $SQL_INSTALL_USER
  /opt/mssql-tools/bin/sqlcmd \
    -S localhost \
    -U sa \
    -P $MSSQL_SA_PASSWORD \
    -Q "CREATE LOGIN [$SQL_INSTALL_USER] WITH PASSWORD=N'$SQL_INSTALL_USER_PASSWORD', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=ON, CHECK_POLICY=ON; ALTER SERVER ROLE [sysadmin] ADD MEMBER [$SQL_INSTALL_USER]"
fi

msg_ok "Installation Completed"

motd_ssh
customize

echo "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
