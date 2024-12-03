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

function check_root()
{
# Root Privilleges check
if [[ "$(id -u)" -ne 0 ]]
then
        msg_error "the script should be initiated with root privileges" >&2
  exit 1
else
        msg_ok "privilege Root: OK"
fi
}

function check_distro()
{
$STD apt-get install lsb-release -y
# Allowed Distro Versions
DEBIAN_VERSIONS=("11" "12")
UBUNTU_VERSIONS=("22.04")
DISTRO=$(lsb_release -is)
VERSION=$(lsb_release -rs)

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



function install_packages()
{
msg_info "Packages installation..."
sleep 1
$STD apt-get update
$STD apt-get install --yes --no-install-recommends \
apache2 \
mariadb-server \
perl \
curl \
jq \
php
msg_info "Php extensions installation..."
$STD apt-get install --yes --no-install-recommends \
php-ldap \
php-imap \
php-apcu \
php-xmlrpc \
php-cas \
php-mysqli \
php-mbstring \
php-curl \
php-gd \
php-simplexml \
php-xml \
php-intl \
php-zip \
php-bz2
$STD systemctl enable mariadb
$STD systemctl enable apache2
msg_ok "Packages and php extensions dompleted"
}

function mariadb_configure()
{
msg_info "MariaDB Configuration..."
sleep 1
SLQROOTPWD=$(openssl rand -base64 48 | cut -c1-12 )
SQLGLPIPWD=$(openssl rand -base64 48 | cut -c1-12 )
$STD systemctl start mariadb
sleep 1

# Set the root password
mysql -e "UPDATE mysql.user SET Password = PASSWORD('${SLQROOTPWD}') WHERE User = 'root'"
# Remove anonymous user accounts
mysql -e "DELETE FROM mysql.user WHERE User = ''"
# Disable remote root login
mysql -e "DELETE FROM mysql.user WHERE User = 'root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
# Remove the test database
mysql -e "DROP DATABASE test"
# Reload privileges
mysql -e "FLUSH PRIVILEGES"
# Create a new database
mysql -e "CREATE DATABASE glpi"
# Create a new user
mysql -e "CREATE USER 'glpi_user'@'localhost' IDENTIFIED BY '$SQLGLPIPWD'"
# Grant privileges to the new user for the new database
mysql -e "GRANT ALL PRIVILEGES ON glpi.* TO 'glpi_user'@'localhost'"
# Reload privileges
mysql -e "FLUSH PRIVILEGES"

# Initialize time zones datas
mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root -p'$SLQROOTPWD' mysql
#Ask tz
dpkg-reconfigure tzdata
$STD systemctl restart mariadb
sleep 1
mysql -e "GRANT SELECT ON mysql.time_zone_name TO 'glpi_user'@'localhost'"
msg_ok "MariaDB installation and Configuration Completed"
}

function install_glpi()
{
msg_info "GLPI installation and Configuration"
# Get download link for the latest release
DOWNLOADLINK=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | jq -r '.assets[0].browser_download_url')
wget -O /tmp/glpi-latest.tgz $DOWNLOADLINK
$STD tar xzf /tmp/glpi-latest.tgz -C /var/www/html/

# Add permissions
chown -R www-data:www-data /var/www/html/glpi
chmod -R 775 /var/www/html/glpi

# Setup vhost
cat > /etc/apache2/sites-available/000-default.conf << EOF
<VirtualHost *:80>
       DocumentRoot /var/www/html/glpi/public  
       <Directory /var/www/html/glpi/public>
                Require all granted
                RewriteEngine On
                RewriteCond %{REQUEST_FILENAME} !-f
                RewriteRule ^(.*)$ index.php [QSA,L]
        </Directory>
        
        LogLevel warn
        ErrorLog \${APACHE_LOG_DIR}/error-glpi.log
        CustomLog \${APACHE_LOG_DIR}/access-glpi.log combined
        
</VirtualHost>
EOF

#Disable Apache Web Server Signature
echo "ServerSignature Off" >> /etc/apache2/apache2.conf
echo "ServerTokens Prod" >> /etc/apache2/apache2.conf

# Setup Cron task
echo "*/2 * * * * www-data /usr/bin/php /var/www/html/glpi/front/cron.php &>/dev/null" >> /etc/cron.d/glpi

#enable session.cookie_httponly
PHP_VERSION=$(php -v | head -n 1 | cut -d " " -f 2 | cut -f1-2 -d".")
cp /etc/php/$PHP_VERSION/apache2/php.ini /etc/php/$PHP_VERSION/apache2/php.ini.back
sed -i -e 's/session.cookie_httponly =/session.cookie_httponly = on/g' /etc/php/$PHP_VERSION/apache2/php.ini   
sed -i -e 's/session.cookie_samesite =/session.cookie_samesite = Lax/g' /etc/php/$PHP_VERSION/apache2/php.ini


#Activation du module rewrite d'apache
$STD a2enmod rewrite 
$STD systemctl restart apache2
}

# function setup_db()
#  {
#  info "Setting up GLPI..."
#  cd /var/www/html/glpi
#  php bin/console db:install --db-name=glpi --db-user=glpi_user --db-password=$SQLGLPIPWD
#  rm -rf /var/www/html/glpi/install
# }

# default_configuration(){
# read -r -p "Would you like to to launch a default Configuration? <y/N> " prompt
# if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
    
#     setup_db
# fi
# }

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
} >> ~/glpi.creds

msg_info "use : cat glpi.creds to retreive all the credentials"
cat glpi.creds
}




check_root
check_distro
network_info
install_packages
mariadb_configure
install_glpi
# default_configuration
save_credentials

motd_ssh
customize

msg_info "Cleaning up"
rm "/opt/v${RELEASE}.zip"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
