# to be called by hermes installer

do_hermesnet_setup()
{

    echo -e "${Red}INSTALLING HERMES-NET${Color_Off}"

    mkdir -p ${TMP_PATH}
    cd ${TMP_PATH}
    rm -rf hermes-net
    git clone https://github.com/Rhizomatica/hermes-net
    cd hermes-net/

    if [ ${HERMES_PRODUCTION} = "false" ]; then
        git fetch
        git checkout development
    fi

    if [ ${MODEM_TYPE} = "mercury" ]; then
        git clone https://github.com/Rhizomatica/mercury
        cd mercury/
        make
        make install
        cd ../ && rm -fr mercury/
    fi

    if [ "${HARDWARE}" = "sbitx" ]; then
        if [ "${HERMES_ROLE}" = "gateway" ]; then
            make install_v2
            make install_gateway
        elif [ "${HERMES_ROLE}" = "remote" ]; then
            make install_v2
        else
            echo "${Red}HERMES ROLE - ${HERMES_ROLE} - not recognized. Aborting.${Color_Off}"
            exit
        fi

        if [ "${MODEM_TYPE}" = "mercury" ]; then
            echo -e "${Red}Installing Mercury${Color_Off}"
            make install_mercury
        fi

        set +e
        systemctl stop sbitx
        set -e

        # Configure user.ini for voice mode if DEFAULT_VOICE is true
        if [[ "$DEFAULT_VOICE" == "true" ]]; then
            echo -e "${Red}Configuring sbitx for DEFAULT_VOICE mode${Color_Off}"
            sed -i 's/^current_profile=.*/current_profile=1/' /etc/sbitx/user.ini
            sed -i 's/^default_profile=.*/default_profile=1/' /etc/sbitx/user.ini
            sed -i 's/^default_profile_fallback_timeout=.*/default_profile_fallback_timeout=-1/' /etc/sbitx/user.ini
            # Set enable_knob_frequency=0 in profile1 section
            sed -i '/^\[profile1\]/,/^\[/{s/^enable_knob_frequency=.*/enable_knob_frequency=0/}' /etc/sbitx/user.ini
        fi

        # Configure custom frequencies and modes if set
        if [[ -n "${DEFAULT_DATA_FREQUENCY:-}" ]]; then
            echo -e "${Red}Setting DEFAULT_DATA_FREQUENCY=${DEFAULT_DATA_FREQUENCY}${Color_Off}"
            sed -i '/^\[profile0\]/,/^\[/{s/^freq=.*/freq='"${DEFAULT_DATA_FREQUENCY}"'/}' /etc/sbitx/user.ini
        fi
        if [[ -n "${DEFAULT_DATA_MODE:-}" ]]; then
            echo -e "${Red}Setting DEFAULT_DATA_MODE=${DEFAULT_DATA_MODE}${Color_Off}"
            sed -i '/^\[profile0\]/,/^\[/{s/^mode=.*/mode='"${DEFAULT_DATA_MODE}"'/}' /etc/sbitx/user.ini
        fi
        if [[ -n "${DEFAULT_VOICE_FREQUENCY:-}" ]]; then
            echo -e "${Red}Setting DEFAULT_VOICE_FREQUENCY=${DEFAULT_VOICE_FREQUENCY}${Color_Off}"
            sed -i '/^\[profile1\]/,/^\[/{s/^freq=.*/freq='"${DEFAULT_VOICE_FREQUENCY}"'/}' /etc/sbitx/user.ini
        fi
        if [[ -n "${DEFAULT_VOICE_MODE:-}" ]]; then
            echo -e "${Red}Setting DEFAULT_VOICE_MODE=${DEFAULT_VOICE_MODE}${Color_Off}"
            sed -i '/^\[profile1\]/,/^\[/{s/^mode=.*/mode='"${DEFAULT_VOICE_MODE}"'/}' /etc/sbitx/user.ini
        fi

        set +e
        systemctl start sbitx
        set -e

    else
        if [ "${HERMES_ROLE}" = "gateway" ]; then
            make install_v1
            make install_gateway
        elif [ "${HERMES_ROLE}" = "remote" ]; then
            make install_v1
        else
            echo "${Red}HERMES ROLE - ${HERMES_ROLE} - not recognized. Aborting.${Color_Off}"
            exit
        fi
        if [[ "${MODEM_TYPE}" = "mercury" ]]; then
            echo -e "${Red}Installing Mercury${Color_Off}"
            make install_mercury
        fi

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
        echo hermes | vncpasswd -f > /root/.vnc/passwd
        # old vnc with tigervnc
        # install -C -g root -o root -m 755 ${INSTALLER_DIRECTORY}/conf/xstartup /root/.vnc/xstartup

        echo -e "${Red}Installing X11 and VNC service files${Color_Off}"

        set +e
        systemctl stop x11
        systemctl stop vnc
        set -e

        install -C -g root -o root -m 644 ${INSTALLER_DIRECTORY}/conf/x11vnc/vnc.service /etc/systemd/system/vnc.service
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

# and make sure we are with latest uucp
    apt-get -y update
    apt-get -y install uucp

    cd ${INSTALLER_DIRECTORY}

    if [ "${HARDWARE}" = "sbitx" ]; then
        set +e
        systemctl daemon-reload
        systemctl enable sbitx
        systemctl enable uucpd

        systemctl start sbitx
        systemctl start uucpd
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
                exit
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
            exit
        fi

    fi

    echo -e "${Red}INSTALLING IWATCH SETUP${Color_Off}"
    cd "${INSTALLER_DIRECTORY}"
    install -C -g root -o root -m 644 conf/iwatch.xml /etc/iwatch/iwatch.xml

    systemctl enable iwatch

}
