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
        local dovecot_conf_src="conf/mail/dovecot.conf"
        if [ "${VERSION_ID:-}" = "12" ]; then
            dovecot_conf_src="conf/mail/dovecot-12.conf"
        fi
        install -C -g root -o root -m 644 "${dovecot_conf_src}" /etc/dovecot/dovecot.conf

        sed -i "s/HERMES_HOSTNAME/${HERMES_HOSTNAME}/g" /etc/dovecot/dovecot.conf

        # Mailbox encryption. Only the Debian 13 configuration carries the
        # dovecot 2.4 mail_crypt settings, so leave Debian 12 stations alone.
        mkdir -p /etc/hermes
        chmod 700 /etc/hermes
        if [ "${MAIL_ENCRYPTION:-true}" = "true" ] && [ "${VERSION_ID:-}" != "12" ]; then
            touch /etc/hermes/mailcrypt
            if [ -s conf/mail/mail-recovery.pem ]; then
                install -C -g root -o root -m 644 conf/mail/mail-recovery.pem /etc/hermes/mail-recovery.pem
                echo -e "${Red}Mailbox encryption on, with recovery copies${Color_Off}"
            else
                echo -e "${Red}Mailbox encryption on. No conf/mail/mail-recovery.pem, so mailbox keys will have NO recovery copy${Color_Off}"
            fi
            # mail_crypt only encrypts what Dovecot writes: deliver through
            # Dovecot's LMTP, not Postfix's own virtual(8), which wrote every
            # message to the maildir in clear. (Not dovecot-lda: it runs as
            # vmail and cannot read the TLS key named in dovecot.conf.)
            apt-get -y install dovecot-lmtpd
            postconf -e "virtual_transport = lmtp:unix:private/dovecot-lmtp"
        else
            rm -f /etc/hermes/mailcrypt
            postconf -e "virtual_transport = virtual"
        fi

        # Postfix's mailbox and alias maps, rebuilt from Dovecot's user list:
        # a reinstall keeps the users (their passwd entries and mailboxes stay),
        # and with maps left empty Postfix would refuse mail for all of them.
        # vmailbox holds "ADDRESS DOMAIN/USER/" per user, as email_create_user
        # writes it; virtual_alias is one line, the forward-to-everyone alias
        # followed by every user.
        dovecot_passwd="/var/mail/vhosts/${HERMES_HOSTNAME}/passwd"
        if [ -n "${HERMES_FWD_EMAIL}" ]; then
            fwd_alias="${HERMES_FWD_EMAIL}"
        else
            fwd_alias="todos@${HERMES_HOSTNAME}"
        fi
        : > /etc/postfix/vmailbox
        if [ -s "${dovecot_passwd}" ]; then
            while IFS=: read -r user_address _; do
                [ -n "${user_address}" ] || continue
                echo "${user_address} ${user_address#*@}/${user_address%@*}/" >> /etc/postfix/vmailbox
                fwd_alias="${fwd_alias} ${user_address}"
            done < "${dovecot_passwd}"
        fi
        echo -n "${fwd_alias}" > /etc/postfix/virtual_alias
        postmap /etc/postfix/vmailbox
        postmap /etc/postfix/virtual_alias

        install -C -g root -o root -m 755 conf/mail/email_create_user /usr/bin/email_create_user
        install -C -g root -o root -m 755 conf/mail/email_delete_user /usr/bin/email_delete_user
        install -C -g root -o root -m 755 conf/mail/email_update_user /usr/bin/email_update_user

        # doveadm (the mailbox encryption key) asks the running Dovecot for
        # the user: it must already run the configuration installed above
        set +e
        systemctl restart dovecot
        set -e

        if ! grep -qs "^root@${HERMES_HOSTNAME}:" /var/mail/vhosts/${HERMES_HOSTNAME}/passwd; then
            email_create_user root@${HERMES_HOSTNAME} "${MAIL_ROOT_PASSWORD}"
        fi

        systemctl enable postfix
        systemctl enable dovecot

    fi

    do_mail_transport_setup
}

# How Postfix hands mail to the radio: over UUCP or NNCP, straight to the
# station or through the gateway.  Done on every run, not only on a first
# install: a station moved between UUCP and NNCP by a reinstall must route its
# mail over the new transport.  When this was first-install only, stations
# reinstalled from NNCP back to UUCP kept handing their mail to nncp-exec,
# which queued it where nothing would ever send it.
do_mail_transport_setup()
{
    cd ${INSTALLER_DIRECTORY}

    echo -e "${Red}MAIL TRANSPORT${Color_Off}"

    # A deployed station keeps a copy of what this changes (main.cf, and the
    # transport map a gateway gets from conf/), with the date, when it does
    # change anything.
    local stamp before_main before_map
    stamp="$(date +%Y%m%d-%H%M%S)"
    before_main="$(postconf -h default_transport transport_maps 2> /dev/null || true)"
    # a remote station on UUCP has no transport map at all
    before_map="$(cat /etc/postfix/transport 2> /dev/null || true)"
    cp -p /etc/postfix/main.cf "/etc/postfix/main.cf.pre-transport-${stamp}" 2> /dev/null || true
    [ -f /etc/postfix/transport ] && cp -p /etc/postfix/transport "/etc/postfix/transport.pre-transport-${stamp}"

    # NNCP replaces UUCP as the radio transport
    if [ "${NNCP_ENABLED:-false}" = "true" ]; then
        MAIL_TRANSPORT="nncp"
    else
        MAIL_TRANSPORT="uucp"
    fi

    if [ ${HERMES_ROLE} = "gateway" ]; then
        postconf -e "default_transport = ${MAIL_TRANSPORT}mx:gw"
    else
        postconf -e "default_transport = ${MAIL_TRANSPORT}:gw"
    fi

    if [ ${HERMES_ROLE} = "gateway" ]; then
        postconf -e "transport_maps = hash:/etc/postfix/transport"
        sed -e "s/\buucp:/${MAIL_TRANSPORT}:/g" conf/transport.${UUCP_NET} > /etc/postfix/transport
        chown root:root /etc/postfix/transport
        chmod 644 /etc/postfix/transport
        postmap /etc/postfix/transport
    elif [ "${NNCP_ENABLED:-false}" = "true" ]; then
        # Over NNCP a remote station reaches the stations it is paired
        # with directly, not through the gateway: route their domains to
        # them.  Everything else still goes to gw.
        postconf -e "transport_maps = hash:/etc/postfix/transport"
        : > /etc/postfix/transport
        # the same rule the mesh re-applies whenever the neighbours change
        hermes-nncp-mesh --postfix-transport "${station_name}" "${INSTALLER_DIRECTORY}"
    else
        # a UUCP remote station sends everything to its gateway
        postconf -X transport_maps
    fi

    # drop the copies that turned out identical
    if [ "$(postconf -h default_transport transport_maps 2> /dev/null)" = "${before_main}" ]; then
        rm -f "/etc/postfix/main.cf.pre-transport-${stamp}"
    else
        echo -e "${Red}Mail transport changed; the previous main.cf is main.cf.pre-transport-${stamp}${Color_Off}"
    fi
    if [ "$(cat /etc/postfix/transport 2> /dev/null)" = "${before_map}" ]; then
        rm -f "/etc/postfix/transport.pre-transport-${stamp}"
    elif [ -f "/etc/postfix/transport.pre-transport-${stamp}" ]; then
        echo -e "${Red}Transport map rewritten from conf/transport.${UUCP_NET}; the previous one is transport.pre-transport-${stamp}${Color_Off}"
    fi

    set +e
    systemctl is-active --quiet postfix && systemctl reload postfix
    set -e
}
