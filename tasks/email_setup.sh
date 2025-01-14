#  to be read by hermes-installer
#
do_email_setup()
{
    cd ${INSTALLER_DIRECTORY}

    echo "${HERMES_HOSTNAME}" >  /etc/mailname

    echo -e "${Red}Set GNU mail as default debian alternative${Color_Off}"
    update-alternatives --set mailx /usr/bin/mail.mailutils

    if [ "${FIRST_INSTALL}" = "true" ]; then

        echo -e "${Red}EMAIL SETUP${Color_Off}"

        set +e

        groupadd -g 5000 vmail
        useradd -s /usr/sbin/nologin -u 5000 -g 5000 vmail
        usermod -aG vmail postfix
        usermod -aG vmail dovecot
        mkdir -p /var/mail/vhosts/${HERMES_HOSTNAME}
        chown -R vmail:vmail /var/mail/vhosts
        chmod -R 775 /var/mail/vhosts
        touch /var/log/dovecot
        chgrp vmail /var/log/dovecot
        chmod 660 /var/log/dovecot

        rm -f /etc/postfix/vmailbox
        touch /etc/postfix/vmailbox
        postmap /etc/postfix/vmailbox

        rm -f /etc/postfix/virtual_alias
        touch /etc/postfix/virtual_alias
        postmap /etc/postfix/virtual_alias

        set -e

        echo "${HERMES_HOSTNAME}" > /etc/postfix/virtual_domains

        echo -e "${Red}Setting up Postfix and Dovecot${Color_Off}"
        install -C -g root -o root -m 644 conf/mail/master.cf /etc/postfix/master.cf
        install -C -g root -o root -m 644 conf/mail/main.cf /etc/postfix/main.cf
        install -C -g root -o root -m 644 conf/mail/dovecot.conf /etc/dovecot/dovecot.conf

        sed -i "s/HERMES_HOSTNAME/${HERMES_HOSTNAME}/g" /etc/dovecot/dovecot.conf

        if [ ${HERMES_ROLE} = "gateway" ]; then
            echo "default_transport = uucpmx:gw" >> /etc/postfix/main.cf
        else
            echo "default_transport = uucp:gw" >> /etc/postfix/main.cf
        fi

        if [ ${HERMES_ROLE} = "gateway" ]; then
            echo "transport_maps = hash:/etc/postfix/transport" >> /etc/postfix/main.cf
            install -C -g root -o root -m 644 conf/transport.${UUCP_NET} /etc/postfix/transport
            postmap /etc/postfix/transport
        fi

        if [ -n "${HERMES_FWD_EMAIL}" ]; then
            echo -n "${HERMES_FWD_EMAIL} " >  /etc/postfix/virtual_alias
        else
            echo -n "todos@${HERMES_HOSTNAME}" >  /etc/postfix/virtual_alias
        fi

        install -C -g root -o root -m 755 conf/mail/email_create_user /usr/bin/email_create_user
        install -C -g root -o root -m 755 conf/mail/email_delete_user /usr/bin/email_delete_user
        install -C -g root -o root -m 755 conf/mail/email_update_user /usr/bin/email_update_user

        email_create_user root@${HERMES_HOSTNAME} caduceu

        systemctl enable postfix
        systemctl enable dovecot
        systemctl start postfix
        systemctl start dovecot

    fi
}
