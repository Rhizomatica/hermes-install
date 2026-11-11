
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
        # under emulation (image builds) MariaDB can take well over the
        # fixed 5 s this used to wait; wait until it answers
        local i
        for i in $(seq 1 120); do
            mysqladmin --silent ping > /dev/null 2>&1 && break
            sleep 1
        done
        if ! mysqladmin --silent ping > /dev/null 2>&1; then
            echo -e "${Red}MariaDB did not start within 120 s${Color_Off}"
            exit 1
        fi
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

    sync_station_frequencies

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

# The GUI's station list (Station information, /api/frequency) is the
# "frequencies" table, which only the seed filled, once, from the aliases in
# /etc/uucp/sys. A reinstall keeps the database, so the list stayed as it was
# seeded: empty if the sys file was not in place yet, or the stations of the
# network the station was first installed for; and an NNCP station, whose
# neighbours the seed never read, had none at all. Make it the stations the
# API sends to, as it lists them (RadioTransport.php): with NNCP as the
# transport (NNCP_ENABLED, which api_setup.sh writes as HERMES_TRANSPORT) the
# NNCP neighbours, the directories of /etc/nncp/neigh named by alias, "self"
# being this station; otherwise the aliases of /etc/uucp/sys. Neither
# "local", this station, nor "gw" on the gateway. Add the
# missing ones and delete the ones no longer there, in one transaction. The
# stations that stay keep the frequency, nickname and mode set for them; one
# that leaves and comes back starts again from the defaults.
sync_station_frequencies()
{
    local alias name aliases=() seen=" "
    local candidates=() src
    if [ "${NNCP_ENABLED:-false}" = "true" ]; then
        src=/etc/nncp/neigh
        for name in /etc/nncp/neigh/*/; do
            [ -d "${name}" ] || continue
            name="$(basename "${name}")"
            [ "${name}" = "self" ] && continue
            candidates+=("${name}")
        done
    else
        src=/etc/uucp/sys
        if [ -f /etc/uucp/sys ]; then
            for name in $(grep -Ev '^\s*#' /etc/uucp/sys | awk '$1 == "alias" { print $2 }'); do
                candidates+=("${name}")
            done
        fi
    fi
    for alias in "${candidates[@]}"; do
        [[ "${alias}" =~ ^[A-Za-z0-9_.-]+$ ]] || continue
        [ "${alias}" = "local" ] && continue
        [ "${alias}" = "gw" ] && [ "${HERMES_ROLE}" = "gateway" ] && continue
        [[ "${seen}" == *" ${alias} "* ]] && continue
        seen+="${alias} "
        aliases+=("${alias}")
    done

    # no stations set up is not a network without stations: keep the list
    # rather than empty it
    if [ "${#aliases[@]}" -eq 0 ]; then
        echo -e "${Red}No stations in ${src}: the GUI's station list is left as it is${Color_Off}"
        return 0
    fi

    local sql="START TRANSACTION;"$'\n' in_list
    in_list="'$(printf "%s','" "${aliases[@]}")"
    in_list="${in_list%,\'}"
    sql+="DELETE FROM frequencies WHERE alias NOT IN (${in_list});"$'\n'
    for alias in "${aliases[@]}"; do
        sql+="INSERT INTO frequencies (alias, nickname, frequency, mode, enable, created_at, updated_at)"
        sql+=" SELECT '${alias}', NULL, 0, 'LSB', 0, NOW(), NOW() FROM DUAL"
        sql+=" WHERE NOT EXISTS (SELECT 1 FROM frequencies WHERE alias = '${alias}');"$'\n'
    done
    sql+="COMMIT;"$'\n'

    echo -e "${Red}GUI station list: ${aliases[*]}${Color_Off}"
    mysql hermes <<< "${sql}"
}
