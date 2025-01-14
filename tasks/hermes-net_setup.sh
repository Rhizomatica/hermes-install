# to be called by hermes installer

do_hermesnet_setup()
{

    echo -e "${Red}INSTALLING HERMES-NET${Color_Off}"

    mkdir -p ${TMP_PATH}
    cd ${TMP_PATH}
    rm -rf hermes-net
    git clone https://github.com/Rhizomatica/hermes-net
    cd hermes-net/

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
    fi

    echo -e "${Red}INSTALLING VARA${Color_Off}"
    rm -rf /opt/VARA
    # VARA 4.7.7
    # cp -a ${INSTALLER_DIRECTORY}/conf/vara/VARA-4.7.7 /opt/VARA
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

    echo -e "${Red}Installing X11 and vpn service files${Color_Off}"

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
    set -e


    cd ${INSTALLER_DIRECTORY}

    if [ "${HARDWARE}" = "sbitx" ]; then
        set +e
        systemctl daemon-reload
        systemctl enable sbitx
        systemctl enable uuardopd

        systemctl start sbitx
        systemctl start uuardopd
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
            systemctl enable uuardopd
            systemctl stop ubitx
            systemctl stop uuardopd
            set -e

            make ispload

            set +e
            systemctl start ubitx
            systemctl start uuardopd
            set -e

        elif [ "${INSTALL_FIRMWARE}" = "0" ]; then
            set +e
            systemctl daemon-reload
            systemctl enable ubitx
            systemctl enable uuardopd

            systemctl start ubitx
            systemctl start uuardopd
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
    systemctl stop iwatch
    systemctl start iwatch

}
