#!/bin/bash
#
# osTicket install script
#
# Author: m3di1
# Version: 1.1.1
#


function warn(){
    echo -e '\e[31m'$1'\e[0m';
}
function info(){
    echo -e '\e[36m'$1'\e[0m';
}

function check_root()
{
# Vérification des privilèges root
if [[ "$(id -u)" -ne 0 ]]
then
        warn "The script should be run as root" >&2
  exit 1
fi
}

function check_distro()
{

DEBIAN_VERSIONS=("11" "12")
UBUNTU_VERSIONS=("22.04")
DISTRO=$(lsb_release -is)
VERSION=$(lsb_release -rs)

if [ "$DISTRO" == "Debian" ]; then
        # Vérifie si la version de Debian est acceptable
        if [[ " ${DEBIAN_VERSIONS[*]} " == *" $VERSION "* ]]; then
                info "your OS: ($DISTRO $VERSION) is compatible."
        else
                warn "your os version ($DISTRO $VERSION) is not compatible."
                warn "would you like to force the installation?"
                info "Are you sure you want to continue? [y/n]"
                read response
                if [ $response == "oui" ]; then
                info "Starting the installation..."
                elif [ $response == "non" ]; then
                info "Quitting..."
                exit 1
                else
                warn "wrong answer, quitting..."
                exit 1
                fi
        fi

# Vérifie si c'est une distribution Ubuntu
elif [ "$DISTRO" == "Ubuntu" ]; then
        # Vérifie si la version d'Ubuntu est acceptable
        if [[ " ${UBUNTU_VERSIONS[*]} " == *" $VERSION "* ]]; then
                info "your OS: ($DISTRO $VERSION) is compatible."
        else
                warn "your os version ($DISTRO $VERSION) is not compatible."
                warn "would you like to force the installation?"
                info "Are you sure you want to continue? [y/n]"
                read response
                if [ $response == "oui" ]; then
                info "Starting the installation..."
                elif [ $response == "non" ]; then
                info "Quitting..."
                exit 1
                else
                warn "wrong answer, quitting..."
                exit 1
                fi
        fi
else
        warn "you are using another distribution that is not compatible with this installation script."
        exit 1
fi
}

function network_info()
{
INTERFACE=$(ip route | awk 'NR==1 {print $5}')
IPADRESS=$(ip addr show $INTERFACE | grep inet | awk '{ print $2; }' | sed 's/\/.*$//' | head -n 1)
HOST=$(hostname)
}

function confirm_installation()
{
warn "this script will start the installation of osTicket"
info "are you sure you want to continue? [y/n]"
read confirm
if [ $confirm == "oui" ]; then
        info "Continuing..."
elif [ $confirm == "non" ]; then
        info "Quitting..."
        exit 1
else
        warn "wrong answer, quitting..."
        exit 1
fi
}

function install_packages()
{
apt update
apt upgrade
apt install --yes --no-install-recommends \
apache2 \
mariadb-server \
perl \
curl \
jq \
unzip \
php
info "Installating php extenstions..."
apt install --yes --no-install-recommends \
php-cli \
php-common \
php-ldap \
php-imap \
php-apcu \
php-xmlrpc \
php-cas \
php-mysqli \
php-mysql \
php-mbstring \
php-curl \
php-gd \
php-simplexml \
php-xml \
php-intl \
php-zip \
php-bz2
systemctl enable mariadb
systemctl enable apache2
}

function mariadb_configure()
{
info "Configuring MariaDB..."
sleep 1
SLQROOTPWD=$(openssl rand -base64 48 | cut -c1-12 )
SQLGLPIPWD=$(openssl rand -base64 48 | cut -c1-12 )
systemctl start mariadb
sleep 1

# Remove anonymous user accounts
mysql -e "DELETE FROM mysql.user WHERE User = ''"
# Disable remote root login
mysql -e "DELETE FROM mysql.user WHERE User = 'root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
# Reload privileges
mysql -e "FLUSH PRIVILEGES"
# Create a new database
mysql -e "CREATE DATABASE osticketdb"
# Create a new user
mysql -e "CREATE USER 'osticket_user'@'localhost' IDENTIFIED BY '$SQLGLPIPWD'"
# Grant privileges to the new user for the new database
mysql -e "GRANT ALL PRIVILEGES ON osticketdb.* TO 'osticket_user'@'localhost'"
# Reload privileges
mysql -e "FLUSH PRIVILEGES"

# Initialize time zones datas
mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root -p'$SLQROOTPWD' mysql
#Ask tz
dpkg-reconfigure tzdata
systemctl restart mariadb
sleep 1
mysql -e "GRANT SELECT ON mysql.time_zone_name TO 'osticket_user'@'localhost'"
}

function install_osticket()
{
info "Downloading and installing the latest version of osticket"
# Get download link for the latest release
DOWNLOADLINK=$(curl -s https://api.github.com/repos/osTicket/osTicket/releases/latest | jq -r '.assets[0].browser_download_url')
wget -O /tmp/osticket-latest.zip $DOWNLOADLINK
unzip /tmp/osticket-latest.zip -d /var/www/html/osTicket/


cp /var/www/html/osTicket/upload/include/ost-sampleconfig.php /var/www/html/osTicket/upload/include/ost-config.php

# Add permissions
chown -R www-data:www-data /var/www/html/osTicket
chmod -R 775 /var/www/html/osTicket

# Setup vhost
cat > /etc/apache2/sites-available/osTicket.conf << EOF
<VirtualHost *:80>
    ServerAdmin admin@$HOST
     DocumentRoot "/var/www/html/osTicket/upload"
     ServerName $IPADRESS
     ServerAlias $HOST
     
     <Directory "/var/www/html/osTicket/upload">
          Options FollowSymlinks
          AllowOverride All
          Require all granted
          Order allow,deny
        Allow from all
     </Directory>

     ErrorLog \${APACHE_LOG_DIR}/osTicket_error.log
     CustomLog \${APACHE_LOG_DIR}/osTicket_access.log combined
</VirtualHost>
EOF

#Disable Apache Web Server Signature
echo "ServerSignature Off" >> /etc/apache2/apache2.conf
echo "ServerTokens Prod" >> /etc/apache2/apache2.conf

a2ensite osTicket.conf

#Activation du module rewrite d'apache
a2enmod rewrite && systemctl restart apache2
}


function display_credentials()
{
systemctl restart apache2
info "=======> osTicket installation details  <======="
info "you can now continue the setup of your instance by connecting to:"
info "http://$IPADRESS or http://$HOST.domain.root" 
echo ""
info "==> DB Credentianls:"
info "root password:           $SLQROOTPWD"
info "osticket_user password:      $SQLGLPIPWD"
info "OsTicket database name:          osticketdb"
info "<==========================================>"
echo ""
}


check_root
check_distro
confirm_installation
network_info
install_packages
mariadb_configure
install_osticket
display_credentials