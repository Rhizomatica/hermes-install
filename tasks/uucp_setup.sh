# to be read by hermes installer

# The pre-agreed startup (uucico -Y, uucpd -F; UUCP_PRE_AGREED) needs
# Rhizomatica uucp 1.07-37 or later.  Where the installed uucp is older,
# build it from Rhizomatica/uucp (branch UUCP_BRANCH) and install it; a
# newer package from the repository replaces it later as usual.
install_uucp_pre_agreed()
{
    local have

    have="$(dpkg-query -W -f='${Version}' uucp 2>/dev/null || true)"
    if [ -n "${have}" ] && dpkg --compare-versions "${have}" ge 1.07-37; then
        return 0
    fi

    echo -e "${Red}BUILDING UUCP WITH THE PRE-AGREED STARTUP (have ${have:-none})${Color_Off}"

    apt-get -y install build-essential dpkg-dev debhelper texinfo libpam0g-dev

    mkdir -p ${TMP_PATH}
    cd ${TMP_PATH}
    rm -rf uucp uucp_*.deb cu_*.deb uucp-dbgsym_*.deb cu-dbgsym_*.deb
    git clone https://github.com/Rhizomatica/uucp
    cd uucp/
    git checkout "${UUCP_BRANCH}"
    dpkg-buildpackage -b -us -uc
    cd ${TMP_PATH}
    # keep the station's /etc/uucp, which the rest of this setup writes
    DEBIAN_FRONTEND=noninteractive dpkg -i --force-confold uucp_*.deb cu_*.deb
    rm -rf uucp uucp_*.deb cu_*.deb uucp-dbgsym_*.deb cu-dbgsym_*.deb uucp_*.buildinfo uucp_*.changes
    cd ${INSTALLER_DIRECTORY}
}

do_uucp_setup()
{

    echo -e "${Red}UUCP SETUP${Color_Off}"

    if [ "${UUCP_PRE_AGREED}" = "true" ]; then
        install_uucp_pre_agreed
    fi

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
    # uucico checks the login itself (-l, against /etc/uucp/passwd).  This
    # used to overwrite the package's own uucp@.service, which the next uucp
    # upgrade put back: Debian's runs in.uucpd, which checks Unix accounts,
    # and every login then failed (the central server, 2026-07-16).  An
    # override in /etc survives upgrades.
    mkdir -p "/etc/systemd/system/uucp@.service.d"
    install -C -g root -o root -m 644 "conf/uucp@.service.d/hermes.conf" "/etc/systemd/system/uucp@.service.d/hermes.conf"
    # no running systemd in an image build (-v): the override applies at boot
    systemctl daemon-reload 2> /dev/null || true

    systemctl enable uucp.socket

    # A station that ran NNCP before: stop what NNCP scheduled.  The daemon
    # and caller would take the modem from uucpd, and the audit log timer
    # would keep queueing packets that nothing sends.  The NNCP spool and
    # keys stay, for a station that goes back to NNCP.
    set +e
    systemctl disable --now nncp-daemon nncp-caller hermes-auditlog.timer 2> /dev/null
    set -e

}
