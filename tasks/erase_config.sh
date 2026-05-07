# to be read by hermes-installer
#
erase_db_setup()
{

    set +e

    echo "DROP USER roundcube; " > sql_commands.sql
    echo "DROP DATABASE roundcubemail;" >> sql_commands.sql

    mysql < sql_commands.sql

    echo "DROP USER hermes; " > sql_commands.sql
    echo "DROP DATABASE hermes;" >> sql_commands.sql

    mysql < sql_commands.sql

    set -e

}
