# to be read by another script


do_system_setup()
{
    echo -e "${Red}HW CLOCK TO UTC${Color_Off}"
    timedatectl set-local-rtc 0

    echo -e "${Red}SETTING TIMEZONE${Color_Off}"
    timedatectl set-timezone ${TIMEZONE}

    echo -e "${Red}SETTING HOSTNAME${Color_Off}"
    hostnamectl set-hostname ${HERMES_HOSTNAME}

    echo "127.0.0.1       localhost" > /etc/hosts
    echo "127.0.1.1       ${HERMES_HOSTNAME}   ${HERMES_HOSTNAME%%.*}" >> /etc/hosts
    echo "::1     localhost ip6-localhost ip6-loopback" >> /etc/hosts
    echo "ff02::1 ip6-allnodes" >> /etc/hosts
    echo "ff02::2 ip6-allrouters" >> /etc/hosts

    cd "${INSTALLER_DIRECTORY}"

    if [ "${HARDWARE}" = "sbitx" ]; then

        echo -e "${Red}Setting default EEPROM boot options${Color_Off}"
        rpi-eeprom-config -a conf/eeprom.cfg

        # rpi-update

        echo -e "${Red}Installing boot configuration config.txt${Color_Off}"
        if [ "${VERSION_ID}" = "12" ]; then
            install -C -g root -o root -m 755 conf/config.txt /boot/firmware/config.txt
        else
            install -C -g root -o root -m 755 conf/config.txt /boot/config.txt
        fi

        echo -e "${Red}Isolating CPU 3 for sbitx and other kernel boot opts${Color_Off}"
        if [ "${VERSION_ID}" = "12" ]; then
            if grep -v -q "isolcpus=3" /boot/firmware/cmdline.txt; then
                sed -i ':a;N;$!ba;s/\n/ /g' /boot/firmware/cmdline.txt
                echo -n " plymouth.ignore-serial-consoles vt.global_cursor_default=0 loglevel=0 splash silent quiet isolcpus=3" >> /boot/firmware/cmdline.txt
            fi
        else
            if grep -v -q "isolcpus=3" /boot/cmdline.txt; then
                echo -n " plymouth.ignore-serial-consoles vt.global_cursor_default=0 loglevel=0 splash silent quiet isolcpus=3" >> /boot/cmdline.txt
            fi
        fi

        echo -e "${Red}Setting up 2GB of swap(file)${Color_Off}"
        echo "CONF_SWAPSIZE=2000" > /etc/dphys-swapfile
        dphys-swapfile swapoff
        dphys-swapfile setup
        dphys-swapfile swapon

        # This is a workaround, check in bookworm if fixed
        echo -e "${Red}Disabling rpi-backlight module${Color_Off}"
        systemctl disable rpi-display-backlight.service
        echo "blacklist rpi_backlight" > /etc/modprobe.d/blacklist-rpi_backlight.conf

        if [ "${VERSION_ID}" = "11" ]; then
            echo -e "${Red}SET HERMES APT SOURCES${Color_Off}"
            install -C -g root -o root -m 644 conf/apt/hermes-11.list /etc/apt/sources.list.d/hermes.list
            wget -qO- http://packages.hermes.radio/hermes/rafael.key | gpg --dearmor -o - > /etc/apt/trusted.gpg.d/hermes.gpg

            echo -e "${Red}SET NODE 18 APT SOURCES${Color_Off}"
            install -C -g root -o root -m 644 conf/node.list /etc/apt/sources.list.d/node.list
            wget -qO- https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor -o - > /etc/apt/trusted.gpg.d/node.gpg

        fi

        if [ "${VERSION_ID}" = "12" ]; then
            echo -e "${Red}SET HERMES APT SOURCES${Color_Off}"
            install -C -g root -o root -m 644 conf/apt/hermes-12.list /etc/apt/sources.list.d/hermes.list
            wget -qO- http://packages.hermes.radio/hermes/rafael.key | gpg --dearmor -o - > /etc/apt/trusted.gpg.d/hermes.gpg

            # removing old cruft from php 7
            rm -f /etc/apt/sources.list.d/php.list
            apt-get update
            dpkg --purge php7.4-cli php7.4-common php7.4-curl php7.4-fpm php7.4-gd php7.4-json php7.4-mbstring php7.4-mysql php7.4-opcache php7.4-readline php7.4-soap php7.4-sqlite3 php7.4-xml
        fi

        echo -e "${Red} apt-get update${Color_Off}"
        apt-get -y update

        echo -e "${Red}INSTALL GNUPG${Color_Off}"
        apt-get -y install gnupg

        echo -e "${Red} apt-get dist-upgrade${Color_Off}"
        apt-get -y dist-upgrade

        echo -e "${Red}Removing Modem Manager and DHCPCD${Color_Off}"
        apt-get -y remove modemmanager dhcpcd5 fake-hwclock triggerhappy openresolv

        echo -e "${Red}Remove old wine e fonts-wine${Color_Off}"
        apt-get -y remove fonts-wine wine

        if [ "${VERSION_ID}" = "12" ]; then
            echo -e "${Red}Getting rid of network-manager and inetd${Color_Off}"
            apt-get -y remove raspberrypi-net-mods network-manager openbsd-inetd

            # debian 11 is giving error for installing npm... ufff install just for debian 12
            echo -e "${Red}Installing npm${Color_Off}"
            apt-get -y install npm
        fi

        echo "postfix postfix/mailname string ${HERMES_HOSTNAME}" | debconf-set-selections
        echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections

        echo -e "${Red}INSTALLING PACKAGES${Color_Off}"
#            tigervnc-standalone-server \
        apt-get -y install uucp \
	        alsa-tools \
            alsa-utils \
            autoconf \
            bash-completion \
            build-essential \
            curl \
            emacs-nox \
            git \
            htop \
            iwatch \
            jq \
            libtool \
            libb64-dev \
            net-tools \
            patch \
            pip \
            sudo \
            vim-nox \
            wmaker \
            xterm \
            zlib1g-dev \
            liblzma-dev \
            ffmpeg \
            libmagic-dev \
            imagemagick \
            php-fpm \
            php-cli \
            php-curl \
            php-gd \
            php-mbstring \
            php-mysql \
            php-soap \
            php-sqlite3 \
            php-xml \
            php-opcache \
            mariadb-server \
            inotify-tools \
            nginx \
            nodejs \
            hostapd \
            openvpn \
            dnsmasq \
            wireless-regdb \
            wireless-tools \
            wpasupplicant \
            dnsmasq \
            iw \
            yarn \
            bc \
            libgtk-3-dev \
            libfftw3-dev \
            libfftw3-double3 \
            libfftw3-long3 \
            libfftw3-single3 \
            libasound2-dev \
            libncurses-dev \
            sqlite3 \
            libsqlite3-dev \
            ntpstat \
            ntp \
            i2c-tools \
            ssl-cert \
            libssl-dev \
            xserver-xorg \
            xinit \
            libcmime \
            vvenc \
            vvdec \
            mozjpeg \
            lpcnet \
            wiringpi \
            libwiringpi-dev \
            netcat-traditional \
            libi2c-dev \
            qt-kiosk-browser \
            plymouth \
            plymouth-themes \
            wireguard \
            wireguard-tools \
            postfix \
            dovecot-core \
            dovecot-pop3d \
            dovecot-imapd \
            hangover-wine \
            libiniparser-dev \
            composer \
            xvfb \
            x11vnc \
            tightvncpasswd \
            ifupdown \
            csdr

        echo -e "${Red}Regenerating .wine directory${Color_Off}"
        set +e
        systemctl stop x11
        systemctl stop vnc
        sleep 3
        rm -rf /root/.wine
        echo -e "${Red}Running wineboot (This might take some time...)${Color_Off}"
        wineboot 2> /dev/null

        systemctl start x11
        systemctl start vnc
        set -e

        echo -e "${Red}SUDOERS NOPASSWD${Color_Off}"
        sed -i '/%sudo/c\%sudo ALL=(ALL) NOPASSWD: ALL' /etc/sudoers

        echo -e "${Red}Enable ssh server${Color_Off}"
        systemctl enable ssh
        systemctl start ssh

        echo -e "${Red}www-data and uucp to sudo group${Color_Off}"
        usermod -a -G sudo www-data
        usermod -a -G sudo uucp
        # usermod -a -G sudo hermes
        usermod -a -G sudo pi
        usermod -a -G ssl-cert pi

        echo -e "${Red}Setting up boot theme${Color_Off}"
        echo "[Daemon]" > /etc/plymouth/plymouthd.conf
        echo "Theme=hermes" >> /etc/plymouth/plymouthd.conf
        echo "ShowDelay=0" >> /etc/plymouth/plymouthd.conf
        tar -C /usr/share/plymouth/themes/ -xvf conf/splash/hermes.tar.gz

        echo -e "${Red}Setting initrd with splash${Color_Off}"
        if [ "${VERSION_ID}" = "12" ]; then
            update-initramfs -u
        else
            update-initramfs -c -k $(uname -r)
            mv /boot/initrd.img-$(uname -r) /boot/initramfs.img
        fi
        echo -e "${Red}Setting up HERMES local UI (kiosk)${Color_Off}"
        systemctl disable getty@tty1.service
        # systemctl stop getty@tty1.service

        echo "{" > /etc/qt-kiosk-browser.conf
        echo "  \"URL\": \"https://127.0.1.1/\"," >> /etc/qt-kiosk-browser.conf
        echo "  \"WebEngineSettings\": {" >> /etc/qt-kiosk-browser.conf
        echo "      \"localContentCanAccessRemoteUrls\": true," >> /etc/qt-kiosk-browser.conf
        echo "      \"AutoLoadImages\": false," >> /etc/qt-kiosk-browser.conf
        echo "      \"AutoLoadIconsForPage\": false," >> /etc/qt-kiosk-browser.conf
        echo "      \"ShowScrollBars    \": false" >> /etc/qt-kiosk-browser.conf
        echo "  }" >> /etc/qt-kiosk-browser.conf
        echo "}" >> /etc/qt-kiosk-browser.conf
# we can remove this once we update the package
        install -C -g root -o root -m 644 conf/qt-kiosk-browser.service /etc/systemd/system/qt-kiosk-browser.service
        systemctl daemon-reload
        systemctl enable qt-kiosk-browser

        echo -e "${Red}Reduce dhclient timeout${Color_Off}"
        install -C -g root -o root -m 644 conf/dhclient.conf /etc/dhcp/dhclient.conf

    else

        echo -e "${Red}ENABLE i386 ARCH${Color_Off}"
        dpkg --add-architecture i386

        echo -e "${Red}ADJUST GRUB${Color_Off}"
        install -C -g root -o root -m 644 conf/grub /etc/default/grub
        /usr/sbin/update-grub

        echo -e "${Red}SET INITIAL APT SOURCES${Color_Off}"
        install -C -g root -o root -m 644 conf/sources.list /etc/apt/sources.list

        echo -e "${Red}INSTALL GNUPG${Color_Off}"
        apt-get -y update
        apt-get -y dist-upgrade
        apt-get -y install gnupg

        echo -e "${Red}SET HERMES APT SOURCES${Color_Off}"
        install -C -g root -o root -m 644 conf/hermes.list /etc/apt/sources.list.d/hermes.list
        install -C -g root -o root -m 644 conf/node.list /etc/apt/sources.list.d/node.list

        echo -e "${Red} packages.hermes.radio key${Color_Off}"
        rm -f rafael.key
        wget http://packages.hermes.radio/hermes/rafael.key
        apt-key add rafael.key
        rm -f rafael.key
        #install -C -g root -o root -m 644 rafael.key /etc/apt/trusted.gpg.d/hermes.key

        echo -e "${Red} nodesoure.com key${Color_Off}"
        rm -f nodesource.gpg.key
        wget https://deb.nodesource.com/gpgkey/nodesource.gpg.key
        apt-key add nodesource.gpg.key
        rm -f nodesource.gpg.key
        #install -C -g root -o root -m 644 nodesource.gpg.key /etc/apt/trusted.gpg.d/nodesource.gpg.key

        echo -e "${Red}RUN apt-get update / dist-upgrade${Color_Off}"
        apt-get -y update
        apt-get -y dist-upgrade

        echo "postfix postfix/mailname string ${HERMES_HOSTNAME}" | debconf-set-selections
        echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections

        echo -e "${Red}INSTALLING PACKAGES${Color_Off}"
        DEBIAN_FRONTEND=noninteractive apt-get -y install uucp \
	        alsa-tools \
            alsa-utils \
            arduino-mk \
            autoconf \
            bash-completion \
            bluez-tools \
            build-essential \
            curl \
            emacs-nox \
            firmware-linux \
            git \
            htop \
            iwatch \
            jq \
            libtool \
            libb64-dev \
            memtest86 \
            memtest86+ \
            mosquitto \
            net-tools \
            patch \
            pip \
            python3 \
            python3-pymysql \
            rxvt \
            sudo \
            vim-nox \
            wmaker \
            xterm \
            zlib1g-dev \
            liblzma-dev \
            ffmpeg \
            libmagic-dev \
            imagemagick \
            vvenc \
            vvdec \
            mozjpeg \
            lpcnet \
            wine \
            wine32 \
            wine64 \
            winetricks \
            libwine \
            libwine:i386 \
            fonts-wine \
            libasound2-plugins:i386 \
            php-fpm \
            php-cli \
            php-curl \
            php-gd \
            php-mbstring \
            php-mysql \
            php-pear \
            php-soap \
            php-sqlite3 \
            php-xml \
            php-opcache \
            composer \
            mariadb-server \
            inotify-tools \
            lm-sensors \
            tigervnc-standalone-server \
            nginx \
            nodejs \
            npm \
            hostapd \
            firmware-realtek \
            firmware-atheros \
            openvpn \
            dnsmasq \
            wireless-regdb \
            wireless-tools \
            wpasupplicant \
            dnsmasq \
            iw \
            linux-headers-amd64 \
            yarn \
            bc \
            dkms \
            python3-gps \
            libcmime \
            python3-tornado \
            python3-alsaaudio \
            python3-hamlib \
            ssl-cert \
            netcat \
            libssl-dev \
            postfix \
            dovecot-core \
            dovecot-pop3d \
            libiniparser-dev \
            dovecot-imapd

        echo -e "${Red}SUDOERS NOPASSWD${Color_Off}"
        sed -i '/%sudo/c\%sudo ALL=(ALL) NOPASSWD: ALL' /etc/sudoers

        echo -e "${Red}www-data and uucp to sudo group${Color_Off}"
        usermod -a -G sudo www-data
        usermod -a -G sudo uucp
        usermod -a -G sudo hermes

    fi

}
