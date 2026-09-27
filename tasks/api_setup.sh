# to be read in hermes-installer

do_api_setup()
{

    echo -e "${Red}HERMES PHP API BACKEND SETUP${Color_Off}"

    mkdir -p ${TMP_PATH}
    cd ${TMP_PATH}
    rm -rf hermes-api/
    git clone https://github.com/Rhizomatica/hermes-api
    cd hermes-api/

    # NNCP stations need the API that speaks NNCP (the uucp tools are not
    # installed there)
    if [ "${NNCP_ENABLED:-false}" = "true" ]; then
        git fetch
        git checkout "${HERMES_API_BRANCH:-nncp-transport}"
    elif [ -n "${HERMES_API_BRANCH:-}" ]; then
        git fetch
        git checkout "${HERMES_API_BRANCH}"
    fi

    echo "APP_NAME=hermes-api" > .env
    echo "APP_ENV=local" >> .env
    echo "APP_KEY=${API_APP_KEY}" >> .env
    echo "APP_DEBUG=true" >> .env
    echo "APP_URL=http://localhost" >> .env
    echo "APP_TIMEZONE=${TIMEZONE}" >> .env
    echo "APP_LANGUAGE=${HERMES_LANGUAGE}" >> .env
    echo "LOG_CHANNEL=stack" >> .env
    echo "LOG_SLACK_WEBHOOK_URL=" >> .env

    echo "DB_CONNECTION=mysql" >> .env
    echo "DB_HOST=127.0.0.1" >> .env
    echo "DB_PORT=3306" >> .env
    echo "DB_SOCKET=/run/mysqld/mysqld.sock" >> .env
    echo "DB_DATABASE=${HERMES_DB}" >> .env
    echo "DB_USERNAME=${HERMES_DB_USER}" >> .env
    echo "DB_PASSWORD=${HERMES_DB_PASSWORD}" >> .env

    echo "CACHE_DRIVER=file" >>  .env
    echo "QUEUE_CONNECTION=sync" >> .env

    echo "MAX_FILE_SIZE=128000000" >> .env
    echo "HERMES_MAX_FILE=20480" >> .env
    echo "HERMES_MAX_SPOOL=71680" >> .env

    # hermes-radio-daemon links sbitx_client to its radio_client
    if [ "${HARDWARE}" = "sbitx" ] || [ "${HARDWARE}" = "hamlib" ]; then
        echo "HERMES_TOOL=/usr/bin/sbitx_client" >> .env
    else
        echo "HERMES_TOOL=/usr/bin/ubitx_client" >> .env
    fi
    echo "HERMES_DOMAIN=${HERMES_HOSTNAME}" >> .env
    echo "HERMES_NAME=${HERMES_HOSTNAME}" >> .env
    echo "HERMES_PATH=/hermes/" >> .env
    echo "HERMES_INBOX=${INBOX_PATH}" >> .env
    echo "HERMES_OUTBOX=outbox/" >> .env

    if [ ${HERMES_ROLE} = "gateway" ]; then
        echo "HERMES_GATEWAY=true" >> .env
        echo "HERMES_ROUTE=hermes" >> .env
    else
        echo "HERMES_GATEWAY=false" >> .env
        echo 'HERMES_ROUTE=gw!hermes' >> .env
    fi
    # radio transport: nncp (encrypted) or uucp
    if [ "${NNCP_ENABLED:-false}" = "true" ]; then
        echo "HERMES_TRANSPORT=nncp" >> .env
        echo "HERMES_UUCP=/var/spool/nncp/" >> .env
    else
        echo "HERMES_TRANSPORT=uucp" >> .env
        echo "HERMES_UUCP=/var/spool/uucp/" >> .env
    fi
    echo "HERMES_UUCP_IN=${INBOX_PATH}" >> .env

    # The pre-agreed UUCP startup (uucico -Y) on the calls the API starts over
    # the air, as caller.sh does on a gateway: the API adds it only to calls
    # to HF stations, never to the gateway's TCP link to the central server.
    # Same conditions as UUCICO_HF_OPTS in hermes-net_setup.
    if [ "${NNCP_ENABLED:-false}" != "true" ] && [ "${UUCP_PRE_AGREED}" = "true" ] \
       && dpkg --compare-versions "$(dpkg-query -W -f='${Version}' uucp 2> /dev/null)" ge 1.07-37; then
        echo "HERMES_UUCICO_HF_OPTS=-Y" >> .env
    fi

    if [ -z "${HERMES_FWD_EMAIL:-}" ]; then
        echo "HERMES_FWD_EMAIL=todos@${HERMES_HOSTNAME}" >> .env
    else
        echo "HERMES_FWD_EMAIL=${HERMES_FWD_EMAIL}" >> .env
    fi
    echo "MAIL_DRIVER=smtp" >> .env
    echo "MAIL_HOST=localhost" >> .env
    echo "MAIL_PORT=25" >> .env  # 25,465,587
    echo "MAIL_USERNAME=root@${HERMES_HOSTNAME}" >> .env
    echo "MAIL_PASSWORD=${MAIL_ROOT_PASSWORD}" >> .env
    echo "MAIL_ENCRYPTION=null" >> .env
    echo "MAIL_FROM_ADDRESS=root@${HERMES_HOSTNAME}" >> .env
    echo "MAIL_FROM_NAME=\"HERMES SYSTEM ${HERMES_HOSTNAME}\"" >> .env


    HOME=/root COMPOSER_ALLOW_SUPERUSER=1 composer install

    HOME=/root COMPOSER_ALLOW_SUPERUSER=1 composer update

    cp -rT . /var/www/station-api/

    mkdir -p /var/www/.gnupg
    chmod 700 /var/www/.gnupg
    chown www-data:www-data /var/www/.gnupg
    # perms !! 777
    mkdir -p /var/www/station-api/storage/app/inbox
    chmod 777 /var/www/station-api/storage/app/inbox
    mkdir -p /var/www/station-api/storage/app/outbox
    chmod 777 /var/www/station-api/storage/app/outbox
    mkdir -p /var/www/station-api/storage/app/downloads
    chmod 777 /var/www/station-api/storage/app/downloads
    mkdir -p /var/www/station-api/storage/app/tmp
    chmod 777 /var/www/station-api/storage/app/tmp
    mkdir -p /var/www/station-api/storage/app/uploads
    chmod 777 /var/www/station-api/storage/app/uploads

    # do we need this?
    mkdir -p /var/www/station-api/storage/app/database/
    chmod 777 /var/www/station-api/storage/app/database/

    rm -f api
    ln -sf /var/www/station-api/public/ /var/www/html/api

    chown -R www-data:www-data /var/www/station-api/

}
