# to be read by hermes installer

do_uucp_setup()
{

    echo -e "${Red}UUCP SETUP${Color_Off}"

    if [[ -f "/etc/cron.daily/uucp" ]]; then
        rm -f /etc/cron.daily/uucp
    fi

    echo "nodename ${CALLSIGN}" > /etc/uucp/config
    echo "pubdir ${INBOX_PATH}" >> /etc/uucp/config

    chmod 644 /etc/uucp/config
    chown root:uucp /etc/uucp/config


    if [ ${HERMES_ROLE} = "gateway" ]; then
        install -C -g uucp -o root -m 644 conf/port /etc/uucp/port

        install -C -g uucp -o root -m 644 conf/passwd /etc/uucp/passwd

        install -C -g uucp -o root -m 644 conf/sys-gw.${UUCP_NET} /etc/uucp/sys
    else
        install -C -g uucp -o root -m 644 conf/port /etc/uucp/port

        install -C -g uucp -o root -m 644 conf/passwd /etc/uucp/passwd

        install -C -g uucp -o root -m 644 conf/sys.${UUCP_NET} /etc/uucp/sys

        sed -i "0,/${UUCP_ALIAS}/s/${UUCP_ALIAS}/local/g" /etc/uucp/sys
    fi
    install -C -g uucp -o root -m 644 "conf/uucp@.service" "/lib/systemd/system/uucp@.service"

    systemctl enable uucp.socket
    systemctl stop uucp.socket
    systemctl start uucp.socket

}
