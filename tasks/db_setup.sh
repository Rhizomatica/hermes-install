# to be read by hermes-installer

db_setup()
{

    if [ "${FIRST_INSTALL}" = "true" ]; then
        echo -e "${Red}INITIAL SQL SETUP AND DB SEED (FOR HERMES)${Color_Off}"


        echo "CREATE USER hermes IDENTIFIED BY 'db_hermes'; " > sql_commands.sql
        echo "CREATE DATABASE hermes;" >> sql_commands.sql
        echo "GRANT ALL PRIVILEGES ON hermes.* TO hermes;" >> sql_commands.sql

        mysql < sql_commands.sql

        cd /var/www/station-api/

        php artisan migrate
        php artisan db:seed


        cd "${INSTALLER_DIRECTORY}"
    fi


}
