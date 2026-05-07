
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

    echo -e "${Red}INITIAL SQL SETUP AND DB SEED (FOR HERMES)${Color_Off}"
    DB_EXISTS=$(mysql -e "SHOW DATABASES LIKE 'hermes';" | grep "hermes" | wc -l)
    if [ "${DB_EXISTS}" -ge 1 ]; then
        echo -e "${Red}Database hermes already exists...${Color_Off}"
        echo -e "${Red}Deleting all DBs and re-installing...${Color_Off}"
        set +e

        echo "DROP USER roundcube; " > sql_commands.sql
        echo "DROP DATABASE roundcubemail;" >> sql_commands.sql

        mysql < sql_commands.sql

        echo "DROP USER hermes; " > sql_commands.sql
        echo "DROP DATABASE hermes;" >> sql_commands.sql

        mysql < sql_commands.sql
        rm -f sql_commands.sql
        set -e
    else
        echo "CREATE USER hermes IDENTIFIED BY 'db_hermes'; " > sql_commands.sql
        echo "CREATE DATABASE hermes;" >> sql_commands.sql
        echo "GRANT ALL PRIVILEGES ON hermes.* TO hermes;" >> sql_commands.sql

        mysql < sql_commands.sql

        cd /var/www/station-api/

        php artisan migrate
        php artisan db:seed

        cd -

        echo -e "${Red}ROUNDCUBE SQL SETUP${Color_Off}"

        echo "CREATE USER roundcube IDENTIFIED BY 'Cm3cmal'; " > sql_commands.sql
        echo "CREATE DATABASE roundcubemail;" >> sql_commands.sql
        echo "GRANT ALL PRIVILEGES ON roundcubemail.* TO roundcube;" >> sql_commands.sql

        mysql < sql_commands.sql
        rm -f sql_commands.sql

        mysql roundcubemail < /var/www/html/mail/SQL/mysql.initial.sql
    fi

    if [ "${virtual_env}" == "true" ]; then
        echo -e "${Red}Stopping MariaDB.${Color_Off}"
        pkill mariadbd
    fi
}
