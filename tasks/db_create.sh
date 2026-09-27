
# The HERMES and Roundcube databases.  Created on the first install; a
# reinstall keeps them and only applies the API's new migrations.  This used
# to drop both databases whenever the hermes one existed, without creating
# them again, so every other run of the installer left the API and the
# webmail without a database.  To start over on purpose, set
# HERMES_ERASE_DB="true" (in the environment or the station file).

db_create()
{
    if [ "${virtual_env}" == "true" ]; then
        echo -e "${Red}Starting MariaDB manually.${Color_Off}"
        rm -rf /run/mysqld/mysqld.sock
        mkdir -p /run/mysqld
        chown -R mysql:mysql /run/mysqld
        sudo -u mysql mariadbd --skip-networking &
        sleep 5
    fi

    if [ "${HERMES_ERASE_DB:-false}" = "true" ]; then
        echo -e "${Red}HERMES_ERASE_DB: deleting the HERMES and Roundcube databases${Color_Off}"
        erase_db_setup
    fi

    echo -e "${Red}SQL SETUP (FOR HERMES)${Color_Off}"
    # by their tables, not by the databases: a run that stopped half way
    # can leave a database without them
    local hermes_tables roundcube_tables
    hermes_tables=$(mysql -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='hermes';")
    roundcube_tables=$(mysql -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='roundcubemail';")

    # The users are (re)set on every run, so that they match the passwords in
    # /etc/hermes/secrets that the API and Roundcube configurations get.
    mysql << EOF
CREATE DATABASE IF NOT EXISTS hermes;
CREATE USER IF NOT EXISTS hermes IDENTIFIED BY '${HERMES_DB_PASSWORD}';
ALTER USER hermes IDENTIFIED BY '${HERMES_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON hermes.* TO hermes;
CREATE DATABASE IF NOT EXISTS roundcubemail;
CREATE USER IF NOT EXISTS roundcube IDENTIFIED BY '${ROUNDCUBE_DB_PASSWORD}';
ALTER USER roundcube IDENTIFIED BY '${ROUNDCUBE_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON roundcubemail.* TO roundcube;
EOF

    # an empty database gets its tables and seed; an existing one only the
    # migrations it does not have yet
    cd /var/www/station-api/
    php artisan migrate --force
    if [ "${hermes_tables}" -eq 0 ]; then
        echo -e "${Red}New HERMES database: seeding it${Color_Off}"
        php artisan db:seed --force
    fi
    cd "${INSTALLER_DIRECTORY}"

    if [ "${roundcube_tables}" -eq 0 ]; then
        if [ -f /var/www/html/mail/SQL/mysql.initial.sql ]; then
            echo -e "${Red}ROUNDCUBE SQL SETUP${Color_Off}"
            mysql roundcubemail < /var/www/html/mail/SQL/mysql.initial.sql
        else
            echo -e "${Red}Roundcube is not installed: its database stays empty (run with FIRST_INSTALL=\"true\")${Color_Off}"
        fi
    fi

    if [ "${virtual_env}" == "true" ]; then
        echo -e "${Red}Stopping MariaDB.${Color_Off}"
        pkill mariadbd
    fi
}
