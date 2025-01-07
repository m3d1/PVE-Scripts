#!/usr/bin/env bash
# Copyright (c) 2021-2024 community-scripts ORG
# Author: m3d1
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

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
function info(){
    echo -e '\e[36m'$1'\e[0m';
}

#Global variables used for this setup 
# HOMER Options, defaults
DB_USER="homer_user"
DB_PASS=$(dd if=/dev/urandom bs=1 count=20 2>/dev/null | base64 | sed 's/[=\+//]//g')
DB_HOST="localhost"
LISTEN_PORT="9060"
CHRONOGRAF_LISTEN_PORT="8888"
INSTALL_INFLUXDB=""

OS=`uname -s`
HOME_DIR=$HOME
CURRENT_DIR=`pwd`
ARCH=`uname -m`

#### NO CHANGES BELOW THIS LINE! 
VERSION=7.7
SETUP_ENTRYPOINT=""
OS=""
DISTRO=""
DISTRO_VERSION=""

unknown_os (){
  echo "Unfortunately, your operating system distribution and version are not supported by this script."
  echo
  echo "You can override the OS detection by setting os= and dist= prior to running this script."
  echo "You can find a list of supported OSes and distributions on our website: https://packagecloud.io/docs#os_distro_version"
  echo
  exit 1
}

gpg_check (){
  echo "Checking for gpg..."
  if command -v gpg > /dev/null; then
    echo "Detected gpg..."
  else
    echo "Installing gnupg for GPG verification..."
    apt-get install -y gnupg
    if [ "$?" -ne "0" ]; then
      echo "Unable to install GPG! Your base system has a problem; please check your default OS's package repositories because GPG should work."
      echo "Repository installation aborted."
      exit 1
    fi
  fi
}

curl_check (){
  echo "Checking for curl..."
  if command -v curl > /dev/null; then
    echo "Detected curl..."
  else
    echo "Installing curl..."
    apt-get install -q -y curl
    if [ "$?" -ne "0" ]; then
      echo "Unable to install curl! Your base system has a problem; please check your default OS's package repositories because curl should work."
      echo "Repository installation aborted."
      exit 1
    fi
  fi
}

install_debian_keyring (){
  if [ "${os,,}" = "debian" ]; then
    echo "Installing debian-archive-keyring which is needed for installing "
    echo "apt-transport-https on many Debian systems."
    apt-get install -y debian-archive-keyring &> /dev/null
  fi
}


detect_os (){
  if [[ ( -z "${os}" ) && ( -z "${dist}" ) ]]; then
    # some systems dont have lsb-release yet have the lsb_release binary and
    # vice-versa
    if [ -e /etc/lsb-release ]; then
      . /etc/lsb-release

      if [ "${ID}" = "raspbian" ]; then
        os=${ID}
        dist=`cut --delimiter='.' -f1 /etc/debian_version`
      else
        os=${DISTRIB_ID}
        dist=${DISTRIB_CODENAME}

        if [ -z "$dist" ]; then
          dist=${DISTRIB_RELEASE}
        fi
      fi

    elif [ `which lsb_release 2>/dev/null` ]; then
      dist=`lsb_release -c | cut -f2`
      os=`lsb_release -i | cut -f2 | awk '{ print tolower($1) }'`

    elif [ -e /etc/debian_version ]; then
      # some Debians have jessie/sid in their /etc/debian_version
      # while others have '6.0.7'
      os=`cat /etc/issue | head -1 | awk '{ print tolower($1) }'`
      if grep -q '/' /etc/debian_version; then
        dist=`cut --delimiter='/' -f1 /etc/debian_version`
      else
        dist=`cut --delimiter='.' -f1 /etc/debian_version`
      fi

    else
      unknown_os
    fi
  fi

  if [ -z "$dist" ]; then
    unknown_os
  fi

  # remove whitespace from OS and dist name
  os="${os// /}"
  dist="${dist// /}"

  echo "Detected operating system as $os/$dist."
}

detect_apt_version (){
  apt_version_full=`apt-get -v | head -1 | awk '{ print $2 }'`
  apt_version_major=`echo $apt_version_full | cut -d. -f1`
  apt_version_minor=`echo $apt_version_full | cut -d. -f2`
  apt_version_modified="${apt_version_major}${apt_version_minor}0"

  echo "Detected apt version as ${apt_version_full}"
}

locate_cmd() {
  # Function to return the full path to the cammnd passed to us
  # Make sure it exists on the system first or else this exits
  # the script execution
  local cmd="$1"
  local valid_cmd=""
  # valid_cmd=$(hash -t $cmd 2>/dev/null)
  valid_cmd=$(command -v $cmd 2>/dev/null)
  if [[ ! -z "$valid_cmd" ]]; then
    echo "$valid_cmd"
  else
    echo "HALT: Please install package for command '$cmd'"
    /bin/kill -s TERM $my_pid
  fi
  return 0
}

create_postgres_user_database(){
  cwd=$(pwd)
  cd /tmp
  sudo -u postgres psql -c "CREATE DATABASE homer_config;"
  sudo -u postgres psql -c "CREATE DATABASE homer_data;"
  sudo -u postgres psql -c "CREATE ROLE ${DB_USER} WITH SUPERUSER LOGIN PASSWORD '$DB_PASS';"
  sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE homer_config to ${DB_USER};"
  sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE homer_data to ${DB_USER};"
  cd $cwd
}

setup_variables (){
  echo "setting up postgre variables ..."
  read -r -p "would you like to change default DB User (y/N) ?" prompt
  if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
    DB_USER=$prompt
  fi
  echo "Default user is : ${DB_USER}"
  read -r -p "would you like to choose youre DB User Password(y/N) ?" prompt
  if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
    DB_PASS=$prompt
  fi
  echo "Default user is : ${DB_PASS}"
}

setup_influxdb (){

  sudo apt-get install -y apt-transport-https
  echo "Setting up InfluxDB Repository"
  wget -qO- https://repos.influxdata.com/influxdata-archive_compat.key | gpg --dearmor > /etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg
  echo "deb [signed-by=/etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg] https://repos.influxdata.com/debian stable main" > /etc/apt/sources.list.d/influxdata.list
  echo "Set up InfluxDB Repository"

  read -r -p "Which version of InfluxDB to install? (1 or 2) " prompt
  if [[ $prompt == "2" ]]; then
    INFLUX="2"
  else
    INFLUX="1"
  fi

  echo "Installing TICK stack ..."
  #sudo apt-get update && sudo apt-get install influxdb kapacitor chronograf telegraf -y
  apt-get update
    if [[ $INFLUX == "2" ]]; then
    apt-get install -y influxdb2
  else
    apt-get install -y influxdb
    wget -q https://dl.influxdata.com/chronograf/releases/chronograf_1.10.1_amd64.deb
    dpkg -i chronograf_1.10.1_amd64.deb
  fi
  apg-get install -y telegraf, kapacitor
  systemctl enable --now influxdb

  yes | cp $CURRENT_DIR/telegraf.conf /etc/telegraf/telegraf.conf
  sudo systemctl restart influxdb
  sudo systemctl restart kapacitor
  sudo systemctl restart chronograf

  sudo systemctl enable kapacitor
  sudo systemctl enable chronograf
  sudo systemctl enable telegraf

  sudo systemctl restart telegraf

  
} 



banner_start() {
  clear;
  echo "**************************************************************"
  echo "                                                              "
  echo "      ,;;;;;,       HOMER SIP CAPTURE (http://sipcapture.org) "
  echo "     ;;;;;;;;;.                                               "
  echo "   ;;;;;;;;;;;;;                                              "
  echo "  ;;;;  ;;;  ;;;;   <--------------- INVITE ---------------   "
  echo "  ;;;;  ;;;  ;;;;    --------------- 200 OK --------------->  "
  echo "  ;;;;  ...  ;;;;                                             "
  echo "  ;;;;       ;;;;   WARNING: This installer is intended for   "
  echo "  ;;;;  ;;;  ;;;;   dedicated/vanilla OS setups without any   "
  echo "  ,;;;  ;;;  ;;;;   customization and with default settings   "
  echo "   ;;;;;;;;;;;;;                                              "
  echo "    :;;;;;;;;;;     THIS SCRIPT IS PROVIDED AS-IS, USE AT     "
  echo "     ^;;;;;;;^      YOUR *OWN* RISK, REVIEW LICENSE & DOCS    "
  echo "                                                              "
  echo "**************************************************************"
  echo;
}

banner_end() {
  # This is the banner displayed at the end of script execution

  local cmd_ip=$(locate_cmd "ip")
  local cmd_head=$(locate_cmd "head")
  local cmd_awk=$(locate_cmd "awk")

  local my_primary_ip=$($cmd_ip route get 8.8.8.8 | $cmd_head -1 | grep -Po '(\d+\.){3}\d+' | tail -n1)

  echo "*************************************************************"
  echo "      ,;;;;,                                                 "
  echo "     ;;;;;;;;.     Congratulations! HOMER has been installed!"
  echo "   ;;;;;;;;;;;;                                              "
  echo "  ;;;;  ;;  ;;;;   <--------------- INVITE ---------------   "
  echo "  ;;;;  ;;  ;;;;    --------------- 200 OK --------------->  "
  echo "  ;;;;  ..  ;;;;                                             "
  echo "  ;;;;      ;;;;   Your system should be now ready to rock!"
  echo "  ;;;;  ;;  ;;;;   Please verify/complete the configuration  "
  echo "  ,;;;  ;;  ;;;;   files generated by the installer below.   "
  echo "   ;;;;;;;;;;;;                                              "
  echo "    :;;;;;;;;;     THIS SCRIPT IS PROVIDED AS-IS, USE AT     "
  echo "     ;;;;;;;;      YOUR *OWN* RISK, REVIEW LICENSE & DOCS    "
  echo "                                                             "
  echo "*************************************************************"
  echo
  echo "     * Configuration Files:"
  echo "         '/usr/local/homer/etc/webapp_config.json'"
  echo "         '/etc/heplify-server.toml'"
  echo
  echo "     * Start/stop HOMER Application Server:"
  echo "         'systemctl start|stop homer-app'"
  echo
  echo "     * Start/stop HOMER SIP Capture Server:"
  echo "         'systemctl start|stop heplify-server'"
  echo
  echo "     * Start/stop HOMER SIP Capture Agent:"
  echo "         'systemctl start|stop heplify'"
  echo
  echo "     * Access HOMER UI:"
  echo "         http://$my_primary_ip:9080"
  echo "         [default: admin/sipcapture]"
  echo
  echo "     * Send HEP/EEP Encapsulated Packets to:"
  echo "         hep://$my_primary_ip:$LISTEN_PORT"
  echo
  echo "     * Prometheus Metrics URL:"
  echo "         http://$my_primary_ip:9096/metrics"
  echo
  # Commenting out Influx and Chronograf
  if [[ "$INSTALL_INFLUXDB" =~ y|yes|Y|Yes|YES ]] ; then
  echo "     * Access InfluxDB UI:"
  echo "         http://$my_primary_ip:$CHRONOGRAF_LISTEN_PORT"
  echo 
  fi
  echo
  echo "**************************************************************"
  echo
  echo " IMPORTANT: Do not forget to send Homer node some traffic! ;) "
  echo " For our capture agents, visit http://github.com/sipcapture "
  echo " For more help and information visit: http://sipcapture.org "
  echo
  echo "**************************************************************"
  echo " Installer Log saved to: $logfile "
  echo
}

install_homer (){

  local base_pkg_list="software-properties-common make cmake gcc g++ dirmngr sudo python3-dev net-tools"
  
  apt-get update && apt-get upgrade -y
  apt-get install -y $base_pkg_list
  wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O- | sudo apt-key add -

  source /etc/os-release
  test $VERSION_ID = "11" && echo "deb [signed-by=/etc/apt/trusted.gpg] http://apt.postgresql.org/pub/repos/apt/ bullseye-pgdg main" > /etc/apt/sources.list.d/postgresql.list
  test $VERSION_ID = "12" && echo "deb [signed-by=/etc/apt/trusted.gpg] http://apt.postgresql.org/pub/repos/apt/ bookworm-pgdg main" > /etc/apt/sources.list.d/postgresql.list

  apt-get update
  
  apt-get install -y postgresql postgresql-contrib
  
  systemctl daemon-reload
  systemctl enable postgresql
  systemctl restart postgresql

  # Commenting out Influx and Chronograf
  printf "Would you like to install influxdb and chronograf? [y/N]: "
  read INSTALL_INFLUXDB 
  case "$INSTALL_INFLUXDB" in 
        "y"|"yes"|"Y"|"Yes"|"YES") setup_influxdb;;
         *) echo "...... [ Exiting ]"; echo;;
  esac

  setup_variables
  create_postgres_user_database

  curl -s https://packagecloud.io/install/repositories/qxip/sipcapture/script.deb.sh?any=true | bash
  apt install heplify -y
  apt install heplify-server -y
  apt install homer-app -y

  sed -i -e "s/homer_user/$DB_USER/g" /usr/local/homer/etc/webapp_config.json
  sed -i -e "s/homer_password/$DB_PASS/g" /usr/local/homer/etc/webapp_config.json

  homer-app -create-table-db-config 
  homer-app -populate-table-db-config

  sed -i -e "s/DBUser\s*=\s*\"postgres\"/DBUser          = \"$DB_USER\"/g" /etc/heplify-server.toml
  sed -i -e "s/DBPass\s*=\s*\"\"/DBPass          = \"$DB_PASS\"/g" /etc/heplify-server.toml
  sed -i -e "s/PromAddr\s*=\s*\"\"/PromAddr        = \"0.0.0.0:9096\"/g" /etc/heplify-server.toml
  sed -i -e "s/HEPTLSAddr            = \"0.0.0.0:9060\"/HEPTLSAddr            = \"0.0.0.0:9061\"/g" /etc/heplify-server.toml
  sed -i -e "s/HEPTCPAddr            = \"\"/HEPTCPAddr            = \"0.0.0.0:9060\"/g" /etc/heplify-server.toml
  
  sudo systemctl enable homer-app
  sudo systemctl restart homer-app
  sudo systemctl status homer-app

  sudo systemctl enable heplify-server
  sudo systemctl restart heplify-server
  sudo systemctl status heplify-server
}

main (){

  banner_start

 #   if ! is_root_user; then
 #     echo "ERROR: You must be the root user. Exiting..." 2>&1
 #     echo  2>&1
 #     exit 1
 #   fi

  detect_os
  curl_check
  gpg_check
  detect_apt_version

  # Need to first run apt-get update so that apt-transport-https can be
  # installed
  echo -n "Running apt-get update... "
  apt-get update &> /dev/null
  echo "done."

  # Install the debian-archive-keyring package on debian systems so that
  # apt-transport-https can be installed next
  install_debian_keyring

  echo -n "Installing apt-transport-https... "
  apt-get install -y apt-transport-https &> /dev/null
  echo "done."


  gpg_key_url="https://packagecloud.io/qxip/sipcapture/gpgkey"
  apt_config_url="https://packagecloud.io/install/repositories/qxip/sipcapture/config_file.list?os=${os}&dist=${dist}&source=script"

  apt_source_path="/etc/apt/sources.list.d/qxip_sipcapture.list"
  apt_keyrings_dir="/etc/apt/keyrings"
  if [ ! -d "$apt_keyrings_dir" ]; then
    install -d -m 0755 "$apt_keyrings_dir"
  fi
  gpg_keyring_path="$apt_keyrings_dir/qxip_sipcapture-archive-keyring.gpg"
    gpg_key_path_old="/etc/apt/trusted.gpg.d/qxip_sipcapture.gpg"

  echo -n "Installing $apt_source_path..."

  # create an apt config file for this repository
  curl -sSf "${apt_config_url}" > $apt_source_path
  curl_exit_code=$?

  if [ "$curl_exit_code" = "22" ]; then
    echo
    echo
    echo -n "Unable to download repo config from: "
    echo "${apt_config_url}"
    echo
    echo "This usually happens if your operating system is not supported by "
    echo "packagecloud.io, or this script's OS detection failed."
    echo
    echo "You can override the OS detection by setting os= and dist= prior to running this script."
    echo "You can find a list of supported OSes and distributions on our website: https://packagecloud.io/docs#os_distro_version"
    echo
    echo "For example, to force Ubuntu Trusty: os=ubuntu dist=trusty ./script.sh"
    echo
    echo "If you are running a supported OS, please email support@packagecloud.io and report this."
    [ -e $apt_source_path ] && rm $apt_source_path
    exit 1
  elif [ "$curl_exit_code" = "35" -o "$curl_exit_code" = "60" ]; then
    echo "curl is unable to connect to packagecloud.io over TLS when running: "
    echo "    curl ${apt_config_url}"
    echo "This is usually due to one of two things:"
    echo
    echo " 1.) Missing CA root certificates (make sure the ca-certificates package is installed)"
    echo " 2.) An old version of libssl. Try upgrading libssl on your system to a more recent version"
    echo
    echo "Contact support@packagecloud.io with information about your system for help."
    [ -e $apt_source_path ] && rm $apt_source_path
    exit 1
  elif [ "$curl_exit_code" -gt "0" ]; then
    echo
    echo "Unable to run: "
    echo "    curl ${apt_config_url}"
    echo
    echo "Double check your curl installation and try again."
    [ -e $apt_source_path ] && rm $apt_source_path
    exit 1
  else
    echo "done."
  fi


  echo -n "Importing packagecloud gpg key... "
  # import the gpg key
  curl -fsSL "${gpg_key_url}" | gpg --dearmor > ${gpg_keyring_path}
  # grant 644 permisions to gpg keyring path
  chmod 0644 "${gpg_keyring_path}"

  # move gpg key to old path if apt version is older than 1.1
  if [ "${apt_version_modified}" -lt 110 ]; then
    # move to trusted.gpg.d

    mv ${gpg_keyring_path} ${gpg_key_path_old}
    # grant 644 permisions to gpg key path
    chmod 0644 "${gpg_key_path_old}"

    # deletes the keyrings directory if it is empty
    if ! ls -1qA $apt_keyrings_dir | grep -q .;then
      rm -r $apt_keyrings_dir
    fi
    echo "Packagecloud gpg key imported to ${gpg_key_path_old}"
  else
    echo "Packagecloud gpg key imported to ${gpg_keyring_path}"
  fi
  echo "done."

  echo -n "Running apt-get update... "
  # update apt on this system
  apt-get update &> /dev/null
  echo "done."

  echo
  echo "The repository is setup! the setup can start."

  install_homer

  banner_end
}

main


function save_credentials()
{
{
info "=======> GLPI installation details  <======="
info "==> GLPI:"
info "GLPI Accounts details:"
info "USER       -  PASSWORD       -  ACCESS"
info "glpi       -  glpi           -  admin account,"
info "tech       -  tech           -  technical account,"
info "normal     -  normal         -  normal account,"
info "post-only  -  postonly       -  post-only account."
echo ""
info "You can continue GPLI deployment from this links:"
info "http://$IPADRESS or http://$HOST" 
echo ""
info "==> MariaDB Details:"
info "root password:           $SLQROOTPWD"
info "glpi_user password:      $SQLGLPIPWD"
info "GLPI database name:          glpi"
info "<==========================================>"
echo ""
} >> ~/homer7.creds

msg_info "use : cat glpi.creds to retreive all the credentials"
}


save_credentials

motd_ssh
customize

msg_info "Cleaning up"
rm "/opt/v${RELEASE}.zip"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"