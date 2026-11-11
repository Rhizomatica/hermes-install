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

    # From the HERMES repository: one version for every station (sensor
    # data compressed by one paq8px version is readable only by the same
    # version), built for any CPU. Building it here with -march=native
    # targeted the emulator's CPU in an image build.
    echo -e "${Red}INSTALLING paq8px${Color_Off}"
    apt-get -y install paq8px


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
            ntpsec

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

    echo -e "${Red}Running apt-get clean{Color_Off}"
    apt-get clean

}
