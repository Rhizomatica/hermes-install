# to be read by hermes installer

# true when the radio is keyed through hermes_shm: an sbitx, or
# hermes-radio-daemon on either backend (sbitx, or a CAT radio such as the
# IC-7100 through Hamlib)
station_has_shm_keyer()
{
    [ "${HARDWARE}" = "sbitx" ] || [ -f /etc/hermes/core.ini ]
}

# /etc/default/nncp-daemon: how the daemon listens on the modem, and whether
# NNCP keys the radio. Called again by do_broadcast_setup once Mercury is
# installed and may be keying the radio itself.
nncp_write_daemon_defaults()
{
    if [ "${MODEM_TYPE}" = "mercury" ]; then
        HF_LISTEN="mercury://127.0.0.1:8300/?mycall=${CALLSIGN}&bw=2300"
    else
        HF_LISTEN="vara://127.0.0.1:8300/?mycall=${CALLSIGN}&bw=2300"
    fi

    # NNCP keys the radio through hermes_shm, as uucpd -o shm did, unless
    # Mercury keys it itself. Mercury's default mercury.ini does (the legacy
    # radio_model = 0 means the HERMES shared memory).
    MERCURY_KEYS="false"
    if [ "${MODEM_TYPE}" = "mercury" ] && \
       [ "$(hermes-nncp-mesh --mercury-ptt)" != "none" ]; then
        MERCURY_KEYS="true"
    fi
    if station_has_shm_keyer && [ "${MERCURY_KEYS}" = "false" ]; then
        HF_LISTEN="${HF_LISTEN}&ptt=hermes"
    fi

    # HF sessions are slow: the default SP deadline is too short
    cat > /etc/default/nncp-daemon << EOF
NNCP_DAEMON_ARGS="-autotoss -hfmodem ${HF_LISTEN}"
NNCPDEADLINE=600
EOF
}

do_nncp_setup()
{

    echo -e "${Red}NNCP SETUP${Color_Off}"

    apt-get -y update
    # python3-cryptography: X25519 and HKDF for hermes-voice-key
    apt-get -y install nncp python3-cryptography

    install -m 755 -o root -g root conf/nncp/hermes-nncp-mesh /usr/local/sbin/hermes-nncp-mesh
    # the voice encryption key, derived from the station's NNCP keys
    install -m 755 -o root -g root conf/nncp/hermes-voice-key /usr/local/sbin/hermes-voice-key
    # nncp-call with the HF deadline: what the API and admins should call
    install -m 755 -o root -g root conf/nncp/hermes-nncp-call /usr/local/sbin/hermes-nncp-call
    install -m 644 -o root -g root conf/nncp/nncp-profile.sh /etc/profile.d/nncp.sh

    # Postfix and the API reach NNCP through the nncp group, never as root
    set +e
    groupadd -r nncp
    useradd -r -g nncp -d /var/spool/nncp -s /usr/sbin/nologin nncp
    usermod -a -G nncp www-data
    set -e

    # received files land in the API inbox, as the UUCP public directory did
    export NNCP_INCOMING="${INBOX_PATH}"

    mkdir -p /var/spool/nncp
    chown root:nncp /var/spool/nncp
    chmod 2770 /var/spool/nncp

    # creates the station keys on first run, then the full-mesh neighbours
    hermes-nncp-mesh "${station_name}" "${INSTALLER_DIRECTORY}"

    chgrp nncp /etc/nncp.hjson
    chmod 640 /etc/nncp.hjson

    # the API and nncp-daemon read the station callsign from here
    echo "${CALLSIGN}" > /etc/nncp-callsign
    chmod 644 /etc/nncp-callsign

    nncp_write_daemon_defaults

    install -m 644 -o root -g root conf/nncp/nncp-daemon.service /lib/systemd/system/nncp-daemon.service
    install -m 644 -o root -g root conf/nncp/nncp-caller.service /lib/systemd/system/nncp-caller.service

    # broadcast area keypair: the gateway sends it, a station installs it
    install -m 755 -o root -g root conf/nncp/areakey /usr/bin/areakey
    install -m 755 -o root -g root conf/nncp/hermes-nncp-area-export /usr/local/sbin/hermes-nncp-area-export

    # audit trail: stations ship theirs to the gateway, the gateway collects
    install -m 755 -o root -g root conf/nncp/auditlog /usr/bin/auditlog
    install -m 755 -o root -g root conf/nncp/hermes-auditlog-send /usr/local/sbin/hermes-auditlog-send
    install -m 644 -o root -g root conf/nncp/hermes-auditlog.service /lib/systemd/system/hermes-auditlog.service
    install -m 644 -o root -g root conf/nncp/hermes-auditlog.timer /lib/systemd/system/hermes-auditlog.timer

    # NNCP replaces the UUCP transport
    set +e
    systemctl daemon-reload
    systemctl disable --now uucp.socket uucpd
    systemctl enable nncp-daemon
    systemctl restart nncp-daemon

    # remote stations call the gateway on a schedule; the gateway only listens
    if [ "${HERMES_ROLE}" = "gateway" ]; then
        systemctl disable --now nncp-caller

        # the gateway collects what the stations send
        mkdir -p /var/log/hermes-audit
        chmod 750 /var/log/hermes-audit
        systemctl disable --now hermes-auditlog.timer
    else
        systemctl enable nncp-caller
        systemctl restart nncp-caller

        systemctl enable hermes-auditlog.timer
        systemctl start hermes-auditlog.timer
    fi
    set -e

    echo -e "${Red}NNCP public keys: /etc/nncp/${station_name}.pub, commit them as conf/nncp/pub/${station_name}${Color_Off}"

}
