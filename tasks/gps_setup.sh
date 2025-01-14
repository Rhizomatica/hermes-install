# to be read...

do_gps_setup()
{

    ## unmaintained, we are migrating away
#    echo -e "${Red}INSTALLING python-gps3${Color_Off}"
#    rm -rf gps3
#    git clone https://github.com/Rhizomatica/gps3.git
#    cd gps3
#    python3 setup.py install
#    cd "${INSTALLER_DIRECTORY}"
#    rm -rf gps3

    echo -e "${Red}INSTALLING paq8px${Color_Off}"
    rm -rf paq8px
    git clone https://github.com/Rhizomatica/paq8px.git
    cd paq8px/build
    cmake -G "Unix Makefiles" -DNDEBUG=ON -DNATIVECPU=ON ..
    make -j2
    strip paq8px
    install -C -g root -o root -m 755 paq8px /usr/bin/paq8px
    cd "${INSTALLER_DIRECTORY}"
    rm -rf paq8px


    echo -e "${Red}INSTALLING hermes-sensors (ps: battery mode hardcoded!)${Color_Off}"
    rm -rf hermes-sensors
    git clone https://github.com/Rhizomatica/hermes-sensors
    cd hermes-sensors
    CFLAGS="-DOPERATION_MODE=0" make
    make install_gps_only
    cd "${INSTALLER_DIRECTORY}"
    # we keep this on disk...

    if [ -n "${HAS_GPS+x}" ] && [ "${HAS_GPS}" = "true" ]; then
        echo -e "${Red}SETTING GPS SOFTWARE${Color_Off}"

        apt-get -y install gpsd \
            gpsd-tools \
            gpsd-clients \
            python3-gps \
            ntp

        cd "${INSTALLER_DIRECTORY}"

        install -C -g root -o root -m 644 conf/ntp.conf /etc/ntpsec/ntp.conf
        install -C -g root -o root -m 644 conf/gpsd /etc/default/gpsd

        set +e
        systemctl enable gpsd
        systemctl stop gpsd
        systemctl start gpsd

        systemctl enable ntpsec
        systemctl stop ntpsec
        systemctl start ntpsec
        set -e

        #if [ ${HERMES_ROLE} = "remote" ]; then
        #    systemctl enable sensors
        #    systemctl stop sensors
        #    systemctl start sensors
        #fi
    fi

}
