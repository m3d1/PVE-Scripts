
#!/bin/bash
#Source : https://docs.paperless-ngx.com/setup/#bare_metal

#Variables
PAPERLESS_VERSION="v1.10.2"
USER="paperless"
PAPERLESS_ADMIN="admin"
PAPERLESS_PASSWORD=$(openssl rand -base64 48 | cut -c1-12 )

REDIS_PASSWORD=PASSWORD=$(openssl rand -base64 48 | cut -c1-12 )
PG_ALREADY_INSTALLED="False"
PG_DB_NAME="paperlessdb"
PG_DB_USER="paperless"
PG_DB_PORT="5432"
PG_DB_PASSWORD=$(openssl rand -base64 48 | cut -c1-12 )

PAPERLESS_CONF_PATH="/opt/paperless/paperless.conf"
PAPERLESS_SECRET_KEY=""
PAPERLESS_LANGUAGE="eng"
CHANGE_OCR_LANG="false"
PAPERLESS_TZ="utc"
CHANGE_TZ="false"

#Prompts list for custom configuration
read -r -p "would you like to skip the installation of PGSQL (y/N) :" prompt
if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
      INSTALL_PG_SERVER="false"
      read -r -p "Enter IP address of FQDN of the remote DB" OE_DB_HOST
else
  read -r -p "would you like to install PGSQL 14 (y/N) :" prompt
  if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
      PG_VERSION=14
  fi
  m_info "PGSQL version $PG_VERSION will be deployed"
fi


read -r -p "would you like to change OCR default language (y/N) :" prompt
if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
      CHANGE_OCR_LANG="true"
      msg_info " To get more details : https://tesseract-ocr.github.io/tessdoc/Data-Files-in-different-versions.html"
      read -r -p "Enter the language you want (ex: fra for french,ara for arabic)" PAPERLESS_LANGUAGE
fi

read -r -p "would you like to change default timezone (UTC) (y/N) :" prompt
if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
      CHANGE_TZ="true"
      msg_info " To get more details : https://docs.djangoproject.com/en/4.1/ref/settings/#std:setting-TIME_ZONE"
      read -r -p "Enter your timezone (ex: Africa/Casablanca , Asia/Tokyo)" PAPERLESS_TZ
fi

#Creation of specific User
adduser $USER --system --home /opt/$USER --group



#dependencies
msg_ok "Installing Python Dependencies"
apt install -y python3 python3-pip python3-dev \
 imagemagick fonts-liberation\
 gnupg libpq-dev default-libmysqlclient-dev pkg-config \
 libmagic-dev libzbar0 poppler-utils \
 build-essential python3-setuptools python3-wheel
msg_ok "Installed Python Dependencies"

#OCR dependencies
msg_ok "Installing OCR Dependencies"
apt install -y unpaper ghostscript icc-profiles-free qpdf liblept5 libxml2 pngquant zlib1g tesseract-ocr

cd /tmp
wget -q https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs10040/ghostscript-10.04.0.tar.gz
$STD tar -xzf ghostscript-10.04.0.tar.gz
cd ghostscript-10.04.0
$STD ./configure
$STD make
$STD sudo make install
msg_ok "Installed OCR Dependencies"

msg_info "Installing JBIG2"
$STD git clone https://github.com/ie13/jbig2enc /opt/jbig2enc
cd /opt/jbig2enc
$STD bash ./autogen.sh
$STD bash ./configure
$STD make
$STD make install
rm -rf /opt/jbig2enc
msg_ok "Installed JBIG2"

#redis 6.0>= and configuration
msg_ok "Installing Redis Server"
$STD apt install redis-server
sed -i -e 's|supervised no|supervised systemd|' /etc/redis/redis.conf
$STD systemctl restart redis.service
$STD apt install net-tools
sed -i -e "s|# requirepass foobared|# requirepass $REDIS_PASSWORD|" /etc/redis/redis.conf
sed -i -e "s|#rename-command FLUSHDB ""|rename-command FLUSHDB ""|" /etc/redis/redis.conf
sed -i -e "s|#rename-command FLUSHALL ""|rename-command FLUSHALL ""|" /etc/redis/redis.conf
sed -i -e "s|#rename-command DEBUG ""|rename-command DEBUG ""|" /etc/redis/redis.conf
sed -i -e "s|rename-command SHUTDOWN SHUTDOWN_MENOT|rename-command FLUSHALL ""|" /etc/redis/redis.conf
sed -i -e "s|rename-command SHUTDOWN SHUTDOWN_MENOT|rename-command DEBUG ""|" /etc/redis/redis.conf
msg_ok "Installed Redis Server"


#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
PG_ALREADY_INSTALLED="False"
export PG_DB_PORT
# Let's  first check if postgres already installed
if [ $INSTALL_PG_SERVER = "True" ]; then
    SERVER_RESULT=`sudo -E -u postgres bash -c "psql -X -p $PG_DB_PORT -c \"SELECT version();\""`
    if [ -z "$SERVER_RESULT" ]; then
        m_info "No postgres database is installed on port $PG_DB_PORT. So we will install it."
    else
        if [[ $SERVER_RESULT == *"PostgreSQL $PG_VERSION"* ]]; then
            m_ok "We already have PostgreSQL Server $PG_VERSION installed and running port $PG_DB_PORT. Skipping it's installation."
            PG_ALREADY_INSTALLED="True"
        else
            m_err "Version other than PostgreSQL $PG_VERSION Server installed on port $PG_DB_PORT. Make sure that you have configured port correctly. Aborting!"
            exit 1
        fi
    fi
else
    CLIENT_RESULT=`psql -V`
    if [ -z "$CLIENT_RESULT" ]; then
        m_info "No PosgreSQL Client installed. Installing it."
    else
        if [[ $CLIENT_RESULT == *"$PG_VERSION"* ]]; then
            m_info "We already have PostgreSQL Client version $PG_VERSION. Skipping installation."
            PG_ALREADY_INSTALLED="True"
        else
            m_warn "Not correct version of PostgreSQL Client installed. Required $PG_VERSION, installed '$CLIENT_RESULT'. We will try to reinstall again."
        fi
    fi
fi

m_info "\n---- Check for PostgreSQL Server Installation ----"
if [ $PG_ALREADY_INSTALLED == "False" ]; then
    sudo apt-get install software-properties-common -y
    sudo curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc|sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
    sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    #sudo add-apt-repository "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -sc)-pgdg main" -y                                 #05/12/2024
    #wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    sudo apt-get update -y
fi

if [ $INSTALL_PG_SERVER = "True" ]; then
    export PG_CONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
    export PG_HBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
    if [ $PG_ALREADY_INSTALLED == "False" ]; then
        m_info "\n---- Install PostgreSQL Server ----"
        sudo apt-get install postgresql-$PG_VERSION -y
        # Edit postgresql.conf to change listen address to '*':
        sudo -u postgres sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONF"
        # Edit postgresql.conf to change port to '$PG_DB_PORT':
        sudo -u postgres sed -i "s/port = 5432/port = $PG_DB_PORT/" "$PG_CONF"
    fi
    # Even if PostgresSQL Server is already installed, we may still want to optimize it for ERP and create DB user.
    export MEM=$(awk '/^MemTotal/ {print $2}' /proc/meminfo)
    export CPU=$(awk '/^processor/ {print $3}' /proc/cpuinfo | wc -l)
    export CONNECTIONS="100"
    # Explicitly set default client_encoding
    sudo -E -u postgres bash -c 'echo "client_encoding = utf8" >> "$PG_CONF"'
    # Explicitly set parameters for ERP/OLTP
    sudo -E -u postgres bash -c 'echo "effective_cache_size = $(( $MEM * 3 / 4 ))kB" >> "$PG_CONF"'
    sudo -E -u postgres bash -c 'echo "checkpoint_completion_target = 0.9" >> "$PG_CONF"'
    sudo -E -u postgres bash -c 'echo "shared_buffers = $(( $MEM / 4 ))kB" >> "$PG_CONF"'
    sudo -E -u postgres bash -c 'echo "maintenance_work_mem = $(( $MEM / 16 ))kB" >> "$PG_CONF"'
    sudo -E -u postgres bash -c 'echo "work_mem = $(( ($MEM - $MEM / 4) / ($CONNECTIONS * 3) ))kB" >> "$PG_CONF"'
    sudo -E -u postgres bash -c 'echo "random_page_cost = 4         # or 1.1 for SSD" >> "$PG_CONF"'
    sudo -E -u postgres bash -c 'echo "effective_io_concurrency = 2 # or 200 for SSD" >> "$PG_CONF"'
    sudo -E -u postgres bash -c 'echo "max_connections = $CONNECTIONS" >> "$PG_CONF"'
    # Now let's create new user
    export PG_DB_USER
    export PG_DB_PASSWORD
    export PG_DB_NAME
    # Append to pg_hba.conf to add password auth:
    $STD sudo -E -u postgres bash -c 'echo "host    all             $PG_DB_USER             all                     md5" >> "$PG_HBA"'
    # Restart so that all new config is loaded:
    $STD sudo service postgresql restart
    m_info "\n---- Creating the paperless PostgreSQL User  ----"
    $STD sudo -u postgres psql -c "CREATE ROLE $PG_DB_USER WITH LOGIN PASSWORD '$PG_DB_PASS';"
    $STD sudo -u postgres psql -c "CREATE DATABASE $PG_DB_NAME WITH OWNER $PG_DB_USER ENCODING 'UTF8' TEMPLATE template0;"
    $STD sudo -u postgres psql -c "ALTER ROLE $PG_DB_USER SET client_encoding TO 'utf8';"
    $STD sudo -u postgres psql -c "ALTER ROLE $PG_DB_USER SET default_transaction_isolation TO 'read committed';"
    $STD sudo -u postgres psql -c "ALTER ROLE $PG_DB_USER SET timezone TO 'UTC'"
    $STD sudo -E -u postgres bash -c "psql -X -p $PG_DB_PORT -c \"CREATE USER $PG_DB_USER WITH CREATEDB NOCREATEROLE NOSUPERUSER PASSWORD '$PG_DB_PASSWORD';\""
    # Restart so that all new config is loaded:
    $STD sudo service postgresql restart
else
    m_info "\n---- Install PostgreSQL Client ----"
    $STD sudo apt-get install postgresql-client-$PG_VERSION -y
fi

#Downloading the source
msg_info "Installing Paperless-ngx"
Paperlessngx=$(wget -q https://github.com/paperless-ngx/paperless-ngx/releases/latest -O - | grep "title>Release" | cut -d " " -f 5)
cd /opt
$STD wget https://github.com/paperless-ngx/paperless-ngx/releases/download/$Paperlessngx/paperless-ngx-$Paperlessngx.tar.xz
$STD tar -xf paperless-ngx-$Paperlessngx.tar.xz -C /opt/
mv paperless-ngx paperless
rm paperless-ngx-$Paperlessngx.tar.xz
cd /opt/paperless
$STD pip3 install --upgrade pip
$STD pip3 install -r requirements.txt
curl -s -o /opt/paperless/paperless.conf https://raw.githubusercontent.com/paperless-ngx/paperless-ngx/main/paperless.conf.example

#Creation of the necessary directories
mkdir -p {consume,data,media,static,trash}
$STD sudo chown $USER:$USER /opt/paperless/media
$STD sudo chown $USER:$USER /opt/paperless/data
$STD sudo chown $USER:$USER /opt/paperless/consume
$STD sudo chown $USER:$USER /opt/paperless/trash

msg_info "Installing Natural Language Toolkit (Patience)"
$STD python3 -m nltk.downloader -d /usr/share/nltk_data all
msg_ok "Installed Natural Language Toolkit"


###MISSING STEPS ####
#paperless Configuration file /opt/paperless/paperless.conf

sed -i -e 's|#PAPERLESS_REDIS=redis://localhost:6379|PAPERLESS_REDIS=redis://localhost:6379|' $PAPERLESS_CONF_PATH
sed -i -e "s|#PAPERLESS_CONSUMPTION_DIR=../consume|PAPERLESS_CONSUMPTION_DIR=/opt/paperless/consume|" $PAPERLESS_CONF_PATH
sed -i -e "s|#PAPERLESS_DATA_DIR=../data|PAPERLESS_DATA_DIR=/opt/paperless/data|" $PAPERLESS_CONF_PATH
sed -i -e "s|#PAPERLESS_MEDIA_ROOT=../media|PAPERLESS_MEDIA_ROOT=/opt/paperless/media|" $PAPERLESS_CONF_PATH
sed -i -e "s|#PAPERLESS_STATICDIR=../static|PAPERLESS_STATICDIR=/opt/paperless/static|" $PAPERLESS_CONF_PATH
#sed -i -e "s|#PAPERLESS_EMPTY_TRASH_DIR=|PAPERLESS_EMPTY_TRASH_DIR=/opt/paperless/trash|" $PAPERLESS_CONF_PATH

sed -i -e 's|#PAPERLESS_DBHOST=localhost|PAPERLESS_DBHOST=localhost|' $PAPERLESS_CONF_PATH
sed -i -e "s|#PAPERLESS_DBPORT=5432|PAPERLESS_DBPORT=$PG_DB_PORT|" $PAPERLESS_CONF_PATH
sed -i -e "s|#PAPERLESS_DBNAME=paperless|PAPERLESS_DBNAME=$PG_DB_NAME|" $PAPERLESS_CONF_PATH
sed -i -e "s|#PAPERLESS_DBUSER=paperless|PAPERLESS_DBUSER=$PG_DB_USER|" $PAPERLESS_CONF_PATH
sed -i -e "s|#PAPERLESS_DBPASS=paperless|PAPERLESS_DBPASS=$PG_DB_PASS|" $PAPERLESS_CONF_PATH
sed -i -e "s|#PAPERLESS_SECRET_KEY=change-me|PAPERLESS_SECRET_KEY=$PAPERLESS_SECRET_KEY|" $PAPERLESS_CONF_PATH

#https://tesseract-ocr.github.io/tessdoc/Data-Files-in-different-versions.html
#sed -i -e "s|#PAPERLESS_OCR_LANGUAGE=eng|#PAPERLESS_OCR_LANGUAGE=$PAPERLESS_LANGUAGE|" $PAPERLESS_CONF_PATH

#https://docs.djangoproject.com/en/4.1/ref/settings/#std:setting-TIME_ZONE
#default = utc ; Personal Africa/Casablanca
#sed -i -e "s|#PAPERLESS_TIME_ZONE=UTC|PAPERLESS_TIME_ZONE=$PAPERLESS_TZ|" $PAPERLESS_CONF_PATH

# PAPERLESS_DBENGINE=postgresql
# PAPERLESS_DBSSLMODE=<mode>
# PAPERLESS_DBSSLROOTCERT=<ca-path>
# PAPERLESS_DBSSLCERT=<client-cert-path>
# PAPERLESS_DBSSLKEY=<client-cert-key>
# PAPERLESS_DB_TIMEOUT=<int>
#PAPERLESS_EMPTY_TRASH_DIR=
#PAPERLESS_URL=https://example.com
#PAPERLESS_CSRF_TRUSTED_ORIGINS=https://example.com # can be set using PAPERLESS_URL
#PAPERLESS_ALLOWED_HOSTS=example.com,www.example.com # can be set using PAPERLESS_URL
#PAPERLESS_CORS_ALLOWED_HOSTS=https://localhost:8080,https://example.com # can be set using PAPERLESS_URL

cd /opt/$USER/src
# This creates the database schema.
$STD python3 manage.py migrate
# This creates your first paperless user
msg_info "Setting up admin Paperless-ngx User & Password"
## From https://github.com/linuxserver/docker-paperless-ngx/blob/main/root/etc/cont-init.d/99-migrations
cat <<EOF | python3 /opt/paperless/src/manage.py shell
from django.contrib.auth import get_user_model
UserModel = get_user_model()
user = UserModel.objects.create_user('$PAPERLESS_ADMIN', password='$PAPERLESS_PASSWORD')
user.is_superuser = True
user.is_staff = True
user.save()
EOF
echo "" >>~/paperless.creds
echo -e "Paperless-ngx WebUI User: \e[32m$PAPERLESS_ADMIN\e[0m" >>~/paperless.creds
echo -e "Paperless-ngx WebUI Password: \e[32m$PAPERLESS_PASSWORD\e[0m" >>~/paperless.creds
echo "" >>~/paperless.creds
msg_ok "Set up admin Paperless-ngx User & Password"

msg_info "Creating Services"
cat <<EOF >/etc/systemd/system/paperless-scheduler.service
[Unit]
Description=Paperless Celery beat
Requires=redis.service

[Service]
WorkingDirectory=/opt/paperless/src
ExecStart=celery --app paperless beat --loglevel INFO

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/etc/systemd/system/paperless-task-queue.service
[Unit]
Description=Paperless Celery Workers
Requires=redis.service
After=postgresql.service

[Service]
WorkingDirectory=/opt/paperless/src
ExecStart=celery --app paperless worker --loglevel INFO

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/etc/systemd/system/paperless-consumer.service
[Unit]
Description=Paperless consumer
Requires=redis.service

[Service]
WorkingDirectory=/opt/paperless/src
ExecStartPre=/bin/sleep 2
ExecStart=python3 manage.py document_consumer

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/etc/systemd/system/paperless-webserver.service
[Unit]
Description=Paperless webserver
After=network.target
Wants=network.target
Requires=redis.service

[Service]
WorkingDirectory=/opt/paperless/src
ExecStart=/usr/local/bin/gunicorn -c /opt/paperless/gunicorn.conf.py paperless.asgi:application

[Install]
WantedBy=multi-user.target
EOF

sed -i -e 's/rights="none" pattern="PDF"/rights="read|write" pattern="PDF"/' /etc/ImageMagick-6/policy.xml

systemctl daemon-reload
$STD systemctl enable -q --now paperless-webserver paperless-scheduler paperless-task-queue paperless-consumer 
msg_ok "Created Services"