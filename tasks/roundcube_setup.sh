# to be read by hermes-installer
#
do_roundcube_setup()
{

    if [ "${FIRST_INSTALL}" = "true" ]; then

        cd ${INSTALLER_DIRECTORY}

        echo -e "${Red}ROUNDCUBE SETUP${Color_Off}"

        rm -f roundcubemail-1.6.0-complete.tar.gz roundcubemail-1.6.3-complete.tar.gz roundcubemail-1.6.4-complete.tar.gz
        wget https://github.com/roundcube/roundcubemail/releases/download/1.6.8/roundcubemail-1.6.8-complete.tar.gz
        tar xvf roundcubemail-1.6.8-complete.tar.gz

        rm -rf /var/www/html/mail
        mv roundcubemail-1.6.8 /var/www/html/mail

        cd /var/www/html/mail

        patch -p0 < ${INSTALLER_DIRECTORY}/conf/roundcube.patch

        echo "<?php" > config/config.inc.php

        echo "\$config = [];" >> config/config.inc.php

        echo "\$config['db_dsnw'] = 'mysql://roundcube:Cm3cmal@localhost/roundcubemail';" >> config/config.inc.php

        echo "\$config['imap_host'] = 'localhost:143';" >> config/config.inc.php
        echo "\$config['smtp_host'] = 'localhost:25';" >> config/config.inc.php

        echo "\$config['smtp_user'] = '%u';" >> config/config.inc.php

        echo "\$config['smtp_pass'] = '%p';" >> config/config.inc.php

#        echo "\$config['support_url'] = 'https://${HERMES_HOSTNAME}';" >> config/config.inc.php

#// Name your service. This is displayed on the login screen and in the window title
        echo "\$config['product_name'] = '<a href=\"..\">HERMES &#11013;</a>';" >> config/config.inc.php

        echo "\$config['username_domain'] = '${HERMES_HOSTNAME}';" >> config/config.inc.php
        #echo "\$config['display_product_info'] = 2;" >> config/config.inc.php

        echo "\$config['des_key'] = 'rcmail-a24ByteDESkey*Str';" >> config/config.inc.php

        #// List of active plugins (in plugins/ directory)
        echo "\$config['plugins'] = [ 'archive', 'zipdownload', ];" >> config/config.inc.php
    
        #   // skin name: folder from skins/
        echo "\$config['skin'] = 'elastic';" >> config/config.inc.php

        # set to hermes language
        echo "\$config['language'] = '${HERMES_LANGUAGE}';" >> config/config.inc.php
    
        chown -R www-data:www-data /var/www/html/mail

        echo -e "${Red}ROUNDCUBE SQL SETUP${Color_Off}"

        echo "CREATE USER roundcube IDENTIFIED BY 'Cm3cmal'; " > sql_commands.sql
        echo "CREATE DATABASE roundcubemail;" >> sql_commands.sql
        echo "GRANT ALL PRIVILEGES ON roundcubemail.* TO roundcube;" >> sql_commands.sql

        mysql < sql_commands.sql

        mysql roundcubemail < SQL/mysql.initial.sql

    fi

    # DO SQL

    # chown www-data:www-data
    #
}
