# to be read by hermes installer
#
# Encrypted broadcast: one file sent once over Mercury's one-way broadcast
# plane, readable by every station of the network and by nobody else.

do_broadcast_setup()
{

    echo -e "${Red}BROADCAST SETUP${Color_Off}"

    mkdir -p ${TMP_PATH}
    cd ${TMP_PATH}
    rm -rf hermes-broadcast
    git clone https://github.com/Rhizomatica/hermes-broadcast
    cd hermes-broadcast/

    # main has no install target yet; the NNCP broadcast work is on its own
    # branch until it is merged
    git fetch
    git checkout "${HERMES_BROADCAST_BRANCH:-nncp-broadcast}"

    make
    make install

    cd ${INSTALLER_DIRECTORY}

    install -m 755 -o root -g root conf/broadcast/hermes-broadcast-send /usr/local/sbin/hermes-broadcast-send
    install -m 755 -o root -g root conf/broadcast/hermes-broadcast-rx /usr/local/sbin/hermes-broadcast-rx
    install -m 644 -o root -g root conf/broadcast/hermes-broadcast.service /lib/systemd/system/hermes-broadcast.service
    install -m 644 -o root -g root conf/broadcast/hermes-broadcast-rx.service /lib/systemd/system/hermes-broadcast-rx.service

    # One keyer for the transmitter. Nothing on the broadcast plane reacts to
    # Mercury's PTT ON/OFF lines (broadcast_daemon does not, and neither would
    # Reticulum), so where the radio is keyed through hermes_shm (sbitx, or
    # hermes-radio-daemon on a CAT radio) Mercury keys it itself. NNCP must then
    # stop keying on the ARQ plane, or the radio would be keyed twice: re-run
    # the mesh and rewrite the daemon defaults, both of which read mercury.ini.
    if station_has_shm_keyer; then
        MERCURY_INI=/etc/mercury/mercury.ini
        mkdir -p /etc/mercury
        touch "${MERCURY_INI}"

        if grep -q '^[[:space:]]*\[ptt\]' "${MERCURY_INI}"; then
            # set method inside [ptt], leaving every other setting alone
            awk '
                /^[[:space:]]*\[/ {
                    if (in_ptt && !done) { print "method = hermes_shm"; done = 1 }
                    in_ptt = ($0 ~ /^[[:space:]]*\[ptt\]/)
                }
                in_ptt && /^[[:space:]]*method[[:space:]]*=/ {
                    if (!done) { print "method = hermes_shm"; done = 1 }
                    next
                }
                { print }
                END { if (in_ptt && !done) print "method = hermes_shm" }
            ' "${MERCURY_INI}" > "${MERCURY_INI}.new"
            mv "${MERCURY_INI}.new" "${MERCURY_INI}"
        else
            printf '\n[ptt]\nmethod = hermes_shm\n' >> "${MERCURY_INI}"
        fi

        NNCP_INCOMING="${INBOX_PATH}" hermes-nncp-mesh "${station_name}" "${INSTALLER_DIRECTORY}"
        nncp_write_daemon_defaults
    fi

    mkdir -p /var/spool/hermes-broadcast/tx /var/spool/hermes-broadcast/rx /var/spool/hermes-broadcast/done
    chown -R root:nncp /var/spool/hermes-broadcast
    chmod -R 2770 /var/spool/hermes-broadcast

    # the mode has to match on both ends: there is no negotiation on the
    # broadcast plane
    cat > /etc/default/hermes-broadcast << EOF
BROADCAST_DAEMON_ARGS="-m ${BROADCAST_MODE:-1} -t /var/spool/hermes-broadcast/tx -r /var/spool/hermes-broadcast/rx -i 127.0.0.1 -p ${BROADCAST_PORT:-8100}"
TX_DIR=/var/spool/hermes-broadcast/tx
RX_DIR=/var/spool/hermes-broadcast/rx
DONE_DIR=/var/spool/hermes-broadcast/done
EOF

    set +e
    systemctl daemon-reload
    # pick up the keying change on both planes
    systemctl restart modem
    systemctl restart nncp-daemon
    systemctl enable hermes-broadcast
    systemctl restart hermes-broadcast
    systemctl enable hermes-broadcast-rx
    systemctl restart hermes-broadcast-rx
    set -e

    if [ "${HERMES_ROLE}" = "gateway" ]; then
        echo -e "${Red}Send the broadcast area key to the stations with:${Color_Off}"
        echo -e "${Red}  hermes-nncp-area-export${Color_Off}"
    fi

}
