# to be called by hermes installer

do_hermesnet_setup()
{

    echo -e "${Red}INSTALLING HERMES-NET${Color_Off}"

    # caller.service as it was before this run: "enabled", "disabled", or
    # not there at all (see the caller block at the end)
    local caller_before
    caller_before="$(systemctl is-enabled caller 2> /dev/null || true)"

    mkdir -p ${TMP_PATH}
    cd ${TMP_PATH}
    rm -rf hermes-net
    git clone https://github.com/Rhizomatica/hermes-net
    cd hermes-net/

    # HERMES_NET_BRANCH picks the branch outright; otherwise NNCP stations
    # need the uuxcomp NNCP transport mode, and Debian 12 its maintenance
    # branch.
    if [ -n "${HERMES_NET_BRANCH}" ]; then
        git checkout "${HERMES_NET_BRANCH}"
    elif [ "${NNCP_ENABLED:-false}" = "true" ]; then
        git fetch
        git checkout nncp-transport
    elif [ "${VERSION_ID}" = "12" ]; then
        git fetch --tags
        git checkout maintenance-debian12
    fi

    if [ ${MODEM_TYPE} = "mercury" ]; then
        # Mercury's build dependencies (its debian/control, less the GUI's)
        apt-get -y install libasound2-dev libpulse-dev libhamlib-dev libssl-dev pkgconf
        git clone https://github.com/Rhizomatica/mercury
        cd mercury/
        make
        make install
        cd ../ && rm -fr mercury/
    fi

    if [ "${HARDWARE}" = "sbitx" ] || [ "${HARDWARE}" = "hamlib" ]; then
        if [ "${HERMES_ROLE}" != "gateway" ] && [ "${HERMES_ROLE}" != "remote" ]; then
            echo -e "${Red}HERMES ROLE - ${HERMES_ROLE} - not recognized. Aborting.${Color_Off}"
            exit 1
        fi

        # hermes-net installs only what goes with the station's radio
        # controller, so that it never replaces the other one's files.
        if [ "${RADIO_CONTROLLER}" = "radiod" ]; then
            make common
            make install_common install_loopback_audio
            if [ "${HARDWARE}" = "sbitx" ]; then
                make install_sbitx_hw
            fi
        elif [ "${RADIO_CONTROLLER}" = "sbitx_controller" ] && [ "${HARDWARE}" = "sbitx" ]; then
            make install_v2
        else
            echo -e "${Red}RADIO_CONTROLLER - ${RADIO_CONTROLLER} - not supported with HARDWARE=${HARDWARE}. Aborting.${Color_Off}"
            exit 1
        fi

        if [ "${HERMES_ROLE}" = "gateway" ]; then
            make install_gateway
        fi

        if [ "${MODEM_TYPE}" = "mercury" ]; then
            echo -e "${Red}Installing Mercury${Color_Off}"
            make install_mercury
        fi

        migrate_hermesnet_units

        if [ "${RADIO_CONTROLLER}" = "radiod" ]; then
            do_radiod_setup
            cd ${TMP_PATH}/hermes-net/
        else
            set +e
            systemctl stop sbitx
            set -e

            configure_radio_profiles /etc/sbitx/user.ini "="

            set +e
            systemctl start sbitx
            set -e
        fi

    else
        if [ "${HERMES_ROLE}" = "gateway" ]; then
            make install_v1
            make install_gateway
        elif [ "${HERMES_ROLE}" = "remote" ]; then
            make install_v1
        else
            echo -e "${Red}HERMES ROLE - ${HERMES_ROLE} - not recognized. Aborting.${Color_Off}"
            exit 1
        fi
        if [[ "${MODEM_TYPE}" = "mercury" ]]; then
            echo -e "${Red}Installing Mercury${Color_Off}"
            make install_mercury
        fi

        migrate_hermesnet_units

    fi

    if [ "${MODEM_TYPE}" = "vara" ]; then
        echo -e "${Red}INSTALLING VARA${Color_Off}"
        # VARA 4.7.7
        # cp -a ${INSTALLER_DIRECTORY}/conf/vara/VARA-4.7.7 /opt/VARA
        rm -rf /opt/VARA
        cp -a ${INSTALLER_DIRECTORY}/conf/vara/VARA-4.8.7 /opt/VARA
        chown -R root:root /opt/VARA/
        chmod -R 755 /opt/VARA/

        #install -C -g root -o root -m 755 ${INSTALLER_DIRECTORY}/conf/vara/VARA-4.7.7.ini.default /opt/VARA/VARA.ini.default
        install -C -g root -o root -m 755 ${INSTALLER_DIRECTORY}/conf/vara/VARA-4.8.7.ini.default /opt/VARA/VARA.ini.default

        sed -i "s/VARA_LICENSE/${VARA_KEY}/g" /opt/VARA/VARA.ini.default
        sed -i "s/VARA_CALLSIGN/${CALLSIGN}/g" /opt/VARA/VARA.ini.default

        echo -e "${Red}VNC SETUP${Color_Off}"
        mkdir -p /root/.vnc
        echo "${VNC_PASSWORD}" | vncpasswd -f > /root/.vnc/passwd
        # old vnc with tigervnc
        # install -C -g root -o root -m 755 ${INSTALLER_DIRECTORY}/conf/xstartup /root/.vnc/xstartup

        echo -e "${Red}Installing X11 and VNC service files${Color_Off}"

        set +e
        systemctl stop x11
        systemctl stop vnc
        set -e

        install -C -g root -o root -m 644 ${INSTALLER_DIRECTORY}/conf/x11vnc/vnc.service /etc/systemd/system/vnc.service
        # without HERMES_HARDENING, VNC answers on the network as it always did
        if [ "${HERMES_HARDENING}" != "true" ]; then
            sed -i -e 's/-listen 127.0.0.1/-listen 0.0.0.0/' \
                   -e '/^# localhost only/d' -e '/^#   ssh -L 5900/d' /etc/systemd/system/vnc.service
        fi
        install -C -g root -o root -m 644 ${INSTALLER_DIRECTORY}/conf/x11vnc/x11.service /etc/systemd/system/x11.service
        install -C -g root -o root -m 755 ${INSTALLER_DIRECTORY}/conf/x11vnc/xstartup /usr/bin/xstartup

        set +e
        systemctl daemon-reload
        systemctl enable x11
        systemctl enable vnc
        systemctl start x11
        systemctl start vnc
    else
        echo -e "${Red}Starting Mercury service${Color_Off}"
        set +e
        systemctl daemon-reload
        systemctl stop modem
        systemctl enable modem
        systemctl start modem
    fi

# disable old cruft
    systemctl disable uuardopd
    set -e

# and make sure we are with latest uucp (skip if using NNCP)
    if [ "${NNCP_ENABLED:-false}" != "true" ]; then
        apt-get -y update
        apt-get -y install uucp
    fi

    cd ${INSTALLER_DIRECTORY}

    # The pre-agreed UUCP startup (UUCP_PRE_AGREED, see common.sh) needs a
    # uucico with -Y: uucpd -F answers with it, the gateway's caller.sh calls
    # with it.  Options a station set itself in /etc/default/uucpd win.
    if [ "${NNCP_ENABLED:-false}" != "true" ] && [ "${UUCP_PRE_AGREED}" = "true" ]; then
        if dpkg --compare-versions "$(dpkg-query -W -f='${Version}' uucp)" ge 1.07-37; then
            if ! grep -qE '^UUCPD_OPTS=' /etc/default/uucpd; then
                echo 'UUCPD_OPTS="-a 127.0.0.1 -p 8300 -r vara -o shm -f 2750p -m -F"' >> /etc/default/uucpd
            fi
            if [ "${HERMES_ROLE}" = "gateway" ] && ! grep -qE '^UUCICO_HF_OPTS=' /etc/default/uucpd; then
                echo 'UUCICO_HF_OPTS="-Y"' >> /etc/default/uucpd
            fi
        else
            echo -e "${Red}uucp $(dpkg-query -W -f='${Version}' uucp) has no pre-agreed startup (1.07-37 or later needed); using the normal UUCP handshake${Color_Off}"
        fi
    fi

    if [ "${HARDWARE}" = "sbitx" ] || [ "${HARDWARE}" = "hamlib" ]; then
        set +e
        systemctl daemon-reload
        # sbitx.service conflicts with radiod.service, but disable the one
        # not in use too, so that it stays off across reboots.
        if [ "${RADIO_CONTROLLER}" = "radiod" ]; then
            controller_unit=radiod.service
            systemctl disable --now sbitx
        else
            controller_unit=sbitx.service
            systemctl disable --now radiod
        fi
        systemctl enable ${controller_unit}
        # The other units know the controller as hermes-radio.service.  The
        # controller must open the snd-aloop cables before the modem, so
        # restart it now: that restarts the modem after it (modem.service is
        # PartOf hermes-radio.service), undoing the controller restarts done
        # under the running modem earlier in the install.
        if [ -x /usr/lib/hermes-net/set_radio_controller.sh ]; then
            /usr/lib/hermes-net/set_radio_controller.sh ${controller_unit}
            systemctl restart hermes-radio.service
        else
            systemctl start ${controller_unit}
        fi
        if [ "${NNCP_ENABLED:-false}" != "true" ]; then
            # UUCP is this station's transport: one installed with NNCP
            # before still runs nncp-daemon and nncp-caller, which take the
            # modem's single TNC connection from uucpd.
            systemctl disable --now nncp-daemon nncp-caller
            systemctl enable uucpd
            systemctl start uucpd
        fi
        set -e

    else

        if [ "${INSTALL_FIRMWARE}" = "1" ]; then

            if [ "${RADUINO_VER}" = "0" ]; then
                CPPFLAGS="-DRADUINO_VER=0" make trx_v1-firmware
            elif [ "${RADUINO_VER}" = "1" ]; then
                CPPFLAGS="-DRADUINO_VER=1" make trx_v1-firmware
            elif [ "${RADUINO_VER}" = "2" ]; then
                CPPFLAGS="-DRADUINO_VER=2" make trx_v1-firmware
            else
                echo -e "${Red}RADUINO_VER VARIABLE NOT PROPERLY SET${Color_Off}"
                exit 1
            fi

            set +e
            systemctl daemon-reload
            systemctl enable ubitx
            systemctl enable uucpd
            systemctl stop ubitx
            systemctl stop uucpd
            set -e

            make ispload

            set +e
            systemctl start ubitx
            systemctl start uucpd
            set -e

        elif [ "${INSTALL_FIRMWARE}" = "0" ]; then
            set +e
            systemctl daemon-reload
            systemctl enable ubitx
            systemctl enable uucpd

            systemctl start ubitx
            systemctl start uucpd
            set -e

        else
            echo -e "${Red}INSTALL_FIRMWARE VARIABLE NOT PROPERLY SET${Color_Off}"
            exit 1
        fi

    fi

    # NNCP replaces uucpd, which the ubitx paths above enable
    if [ "${NNCP_ENABLED:-false}" = "true" ]; then
        set +e
        systemctl disable --now uucpd
        set -e
    fi

    # A UUCP gateway calls the central server and, on the schedules set in
    # the GUI, its stations: caller.sh, which install_gateway installs.  No
    # installer ever enabled it: deployed gateways had it enabled by hand.
    # So a new gateway gets it enabled, and a gateway that has it keeps its
    # state (a deployed gateway with it disabled stays so).  A station
    # reinstalled under another name that is not a gateway stops calling as
    # one; any other station keeps what it had.  An NNCP gateway uses
    # nncp-caller instead.
    set +e
    systemctl daemon-reload 2> /dev/null
    if [ "${HERMES_ROLE}" = "gateway" ] && [ "${NNCP_ENABLED:-false}" != "true" ]; then
        if [ "${caller_before}" = "enabled" ] || [ -z "${caller_before}" ] \
           || [ "${ORIGINAL_HOSTNAME:-}" != "${HERMES_HOSTNAME}" ]; then
            systemctl enable caller
            systemctl restart caller
        else
            echo -e "${Red}caller.service is ${caller_before} on this gateway: leaving it so${Color_Off}"
        fi
    elif [ "${caller_before}" = "enabled" ] && [ "${ORIGINAL_HOSTNAME:-}" != "${HERMES_HOSTNAME}" ]; then
        systemctl disable --now caller
    fi
    set -e

    echo -e "${Red}INSTALLING IWATCH SETUP${Color_Off}"
    cd "${INSTALLER_DIRECTORY}"
    install -C -g root -o root -m 644 conf/iwatch.xml /etc/iwatch/iwatch.xml

    systemctl enable iwatch

}
