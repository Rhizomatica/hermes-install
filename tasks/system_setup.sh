# to be read by another script

PACKAGES="uucp \
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
vvenc \
vvdec \
mozjpeg \
lpcnet \
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
iw \
bc \
sqlite3 \
ssl-cert \
libssl-dev \
libcmime \
postfix \
dovecot-core \
dovecot-pop3d \
dovecot-imapd \
dovecot-lmtpd \
libiniparser-dev \
composer \
libgtk-3-dev \
libfftw3-dev \
libfftw3-double3 \
libfftw3-long3 \
libfftw3-single3 \
libasound2-dev \
libncurses-dev \
libsqlite3-dev \
ntpstat \
ntpsec \
i2c-tools \
netcat-traditional \
libi2c-dev \
plymouth \
plymouth-themes \
ifupdown \
binfmt-support \
csdr"

do_system_setup()
{
    echo -e "${Red}SETTING TIMEZONE${Color_Off}"
    ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
    
    echo -e "${Red}SETTING HOSTNAME${Color_Off}"
    echo ${HERMES_HOSTNAME} > /etc/hostname
    hostname ${HERMES_HOSTNAME}

    echo "127.0.0.1       localhost" > /etc/hosts
    echo "127.0.1.1       ${HERMES_HOSTNAME}   ${HERMES_HOSTNAME%%.*}" >> /etc/hosts
    echo "::1     localhost ip6-localhost ip6-loopback" >> /etc/hosts
    echo "ff02::1 ip6-allnodes" >> /etc/hosts
    echo "ff02::2 ip6-allrouters" >> /etc/hosts

    cd "${INSTALLER_DIRECTORY}"

    if [ "${HARDWARE}" = "sbitx" ]; then
        # arm64
        if [ "${VERSION_ID:-}" = "13" ]; then
            # dont exit if this fails, it might not be installed and we can continue
            set +e
            apt-get -y remove systemd-zram-generator rpi-systemd-config cloud-init
            set -e
            apt -y autoremove
            apt-get -y install dphys-swapfile
        fi

        if [ "${virtual_env}" = false ]; then
            echo -e "${Red}Setting up 2GiB of swap(file)${Color_Off}"
            echo "CONF_SWAPSIZE=2048" > /etc/dphys-swapfile
            dphys-swapfile swapoff
            dphys-swapfile setup
            dphys-swapfile swapon
        else
            echo -e "${Red}Set 'most' to initramfs${Color_Off}"
            sed -i 's|^MODULES=.*|MODULES=most|' /etc/initramfs-tools/initramfs.conf
        fi

        install -C -g root -o root -m 755 conf/config.txt /boot/firmware/config.txt

        if [[ "$DISPLAY_TYPE" == "v1" ]]; then
            echo -e "${Red}Setting Display Type v1...${Color_Off}"
            # do nothing
        elif [[ "$DISPLAY_TYPE" == "v2" ]]; then
            echo -e "${Red}Setting Display Type v2...${Color_Off}"
            echo "dtoverlay=vc4-kms-dsi-ili9881-7inch,rotation=270,swapxy,invy" >> /boot/firmware/config.txt
        else
            echo -e "${Red}Unknown DISPLAY_TYPE: $DISPLAY_TYPE${Color_Off}"
            exit 1
        fi

        echo -e "${Red}Isolating CPU 3 for sbitx and other kernel boot opts${Color_Off}"
        if grep -v -q "isolcpus=3" /boot/firmware/cmdline.txt; then
            sed -i ':a;N;$!ba;s/\n/ /g' /boot/firmware/cmdline.txt
            echo -n " plymouth.ignore-serial-consoles vt.global_cursor_default=0 loglevel=0 splash silent mitigations=off quiet isolcpus=3" >> /boot/firmware/cmdline.txt
        fi


        ## REMOVED 22/02/2026 - no bug anymore in trixie?
        # This is a workaround, check in bookworm if fixed
        #echo -e "${Red}Disabling rpi-backlight module${Color_Off}"
        #systemctl disable rpi-display-backlight.service
        #echo "blacklist rpi_backlight" > /etc/modprobe.d/blacklist-rpi_backlight.conf

        echo -e "${Red}SET HERMES APT SOURCES${Color_Off}"
        if [ "${VERSION_ID:-}" = "13" ]; then
            install -C -g root -o root -m 644 conf/apt/hermes-13.list /etc/apt/sources.list.d/hermes.list
            wget --no-check-certificate -qO- https://debian.hermes.radio/hermes/hermes.key | gpg --dearmor -o - > /etc/apt/trusted.gpg.d/hermes.gpg
        else
            install -C -g root -o root -m 644 conf/apt/hermes-12.list /etc/apt/sources.list.d/hermes.list
            wget --no-check-certificate -qO- http://packages.hermes.radio/hermes/rafael.key | gpg --dearmor -o - > /etc/apt/trusted.gpg.d/hermes.gpg
        fi

        if [ "${VERSION_ID:-}" = "12" ]; then
            # removing old cruft from php 7, in case of upgrading from older version, aka Debian 11
            rm -f /etc/apt/sources.list.d/php.list
            apt-get -y update
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

        echo -e "${Red}Getting rid of network-manager and inetd${Color_Off}"
        apt-get -y remove raspberrypi-net-mods network-manager openbsd-inetd

        echo -e "${Red}Installing npm${Color_Off}"
        apt-get -y install npm

        echo "postfix postfix/mailname string ${HERMES_HOSTNAME}" | debconf-set-selections
        echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections

        if [ "${MODEM_TYPE}" = "vara" ]; then
            PACKAGES="${PACKAGES} \
            hangover-wine \
            xvfb \
            x11vnc \
            tightvncpasswd \
            xserver-xorg \
            xinit"
        fi

        echo -e "${Red}INSTALLING PACKAGES${Color_Off}"
        DEBIAN_FRONTEND=noninteractive apt-get -y install ${PACKAGES}

        # install different versions of qt-kiosk-browser depending on the DISPLAY_TYPE
        echo -e "${Red}Installing qt-kiosk-browser${Color_Off}"
        rm -rf /home/pi/.cache/qt-kiosk-browser/ /home/pi/.cache/qtshadercache-arm64-little_endian-lp64/ /home/pi/.local/share/qt-kiosk-browser/
        dpkg --purge qt-kiosk-browser-rot
        apt-get -y install qt-kiosk-browser unclutter openbox

        echo -e "${Red}Installing box64${Color_Off}"
        dpkg --purge box64-rpi4arm64
        dpkg --purge box64

        mkdir -p box64
        dpkg-deb -xv conf/packages/box64_0.2.4-1_arm64.deb box64
        rm -rf /opt/box64
        mv box64/opt/box64 /opt/
        install -C -g root -o root -m 644 box64/etc/binfmt.d/box64.conf /etc/binfmt.d/box64.conf
        rm -r box64
        # dpkg -i conf/packages/box64_0.2.4-1_arm64.deb

        echo -e "${Red}Installing NESC${Color_Off}"
        mkdir -p nesc
        dpkg-deb -xv conf/packages/nesc_0.2-2_amd64.deb nesc
        rm -rf /opt/nesc
        mv nesc/opt/nesc /opt/
        rm -r nesc

        echo -e "${Red}Running apt-get clean${Color_Off}"
        apt-get clean

        if [ "${MODEM_TYPE}" = "vara" ]; then
            echo -e "${Red}Stopping services and deleting .wine${Color_Off}"
            set +e
            systemctl stop x11
            systemctl stop vnc
            systemctl disable modem
            set -e
            sleep 3
            rm -rf /root/.wine
            echo -e "${Red}Running wineboot (This might take some time...)${Color_Off}"
            wineboot 2> /dev/null

            set +e
            systemctl start x11
            systemctl start vnc
            set -e
        else
            set +e
            systemctl disable x11
            systemctl disable vnc
            set -e
        fi

        if [ "${HERMES_HARDENING}" = "true" ]; then
            echo -e "${Red}SUDOERS: scoped policy for the web API${Color_Off}"
            install -C -g root -o root -m 440 conf/sudoers.d/hermes /etc/sudoers.d/hermes
            if command -v visudo > /dev/null; then
                visudo -c -f /etc/sudoers.d/hermes
            fi
            # undo the NOPASSWD line an earlier install may have left
            sed -i '/^%sudo/c\%sudo ALL=(ALL:ALL) ALL' /etc/sudoers
        else
            echo -e "${Red}SUDOERS NOPASSWD${Color_Off}"
            sed -i '/%sudo/c\%sudo ALL=(ALL) NOPASSWD: ALL' /etc/sudoers
        fi

        # only harden sshd when we ship keys, otherwise the station locks us out
        if [ "${HERMES_HARDENING}" = "true" ] && [ -s conf/ssh/authorized_keys ]; then
            echo -e "${Red}SSH: key-only access${Color_Off}"
            mkdir -p /etc/ssh/sshd_config.d
            install -C -g root -o root -m 644 conf/ssh/hermes.conf /etc/ssh/sshd_config.d/hermes.conf
            for admin_home in /root /home/pi; do
                mkdir -p "${admin_home}/.ssh"
                install -C -m 600 conf/ssh/authorized_keys "${admin_home}/.ssh/authorized_keys"
            done
            chown -R pi:pi /home/pi/.ssh
        else
            echo -e "${Red}SSH: password login stays enabled${Color_Off}"
        fi

        echo -e "${Red}Enable ssh server${Color_Off}"
        systemctl enable ssh

        echo -e "${Red}www-data and uucp to sudo group${Color_Off}"
        usermod -a -G sudo www-data
        usermod -a -G sudo uucp

        set +e
        echo -e "${Red}Creating (or trying to) pi user${Color_Off}"
        useradd -s /bin/bash -m -G sudo,video,adm,dialout,cdrom,audio,plugdev,games,users,input,render,netdev,spi,gpio,i2c,ssl-cert pi
        echo "pi:${PI_PASSWORD}" | chpasswd
        set -e

        usermod -a -G sudo,video,adm,dialout,cdrom,audio,plugdev,games,users,input,render,netdev,spi,gpio,i2c,ssl-cert pi

        echo -e "${Red}Setting up boot theme${Color_Off}"
        echo "[Daemon]" > /etc/plymouth/plymouthd.conf
        echo "Theme=hermes" >> /etc/plymouth/plymouthd.conf
        echo "ShowDelay=0" >> /etc/plymouth/plymouthd.conf

        if [[ "$DISPLAY_TYPE" == "v1" ]]; then
            echo -e "${Red}Installing HERMES splash screen for v1${Color_Off}"
            rm -rf /usr/share/plymouth/themes/hermes
            tar -C /usr/share/plymouth/themes/ -xvf conf/splash/hermes.tar.gz
        elif [[ "$DISPLAY_TYPE" == "v2" ]]; then
            echo -e "${Red}Installing HERMES splash screen for v2${Color_Off}"
            rm -rf /usr/share/plymouth/themes/hermes
            tar -C /usr/share/plymouth/themes/ -xvf conf/splash/hermes-hi.tar.gz
        else
            echo "Unknown DISPLAY_TYPE: $DISPLAY_TYPE"
            exit 1
        fi

        update-initramfs -u

        echo -e "${Red}Setting up HERMES local UI (kiosk)${Color_Off}"
        systemctl disable getty@tty1.service

        # Default to false if DEFAULT_VOICE is unset
        DEFAULT_VOICE="${DEFAULT_VOICE:-false}"

        echo "{" > /etc/qt-kiosk-browser.conf
        echo "  \"URL\": \"https://127.0.1.1/\"," >> /etc/qt-kiosk-browser.conf
        if [[ "$DEFAULT_VOICE" == "true" ]]; then
            echo "  \"RestartTimeout\": 0," >> /etc/qt-kiosk-browser.conf
        fi
        echo "  \"VirtualKeyboardLocale\": \"en_GB\"," >> /etc/qt-kiosk-browser.conf
        echo "  \"VirtualKeyboardAvailableLocales\": [\"pt_BR\", \"es_ES\", \"fr_FR\", \"en_GB\", \"ar_AR\"]," >> /etc/qt-kiosk-browser.conf
        echo "  \"WebEngineSettings\": {" >> /etc/qt-kiosk-browser.conf
        echo "      \"localContentCanAccessRemoteUrls\": true" >> /etc/qt-kiosk-browser.conf
        echo "  }" >> /etc/qt-kiosk-browser.conf
        echo "}" >> /etc/qt-kiosk-browser.conf

        if [[ "$DISPLAY_TYPE" == "v1" ]]; then
            # we can remove this once we update the package
            install -C -g root -o root -m 644 conf/qt-kiosk-browser-normal.service /etc/systemd/system/qt-kiosk-browser.service
        elif [[ "$DISPLAY_TYPE" == "v2" ]]; then
            install -C -g root -o root -m 644 conf/qt-kiosk-browser-rot.service /etc/systemd/system/qt-kiosk-browser.service
            install -C -g root -o root -m 644 conf/dot_xinitrc /home/pi/.xinitrc
            echo "allowed_users=anybody" > /etc/X11/Xwrapper.config
            chmod 644 /etc/X11/Xwrapper.config
        else
            echo "Unknown DISPLAY_TYPE: $DISPLAY_TYPE"
            exit 1
        fi

        systemctl enable qt-kiosk-browser

        echo -e "${Red}Reduce dhclient timeout${Color_Off}"
        install -C -g root -o root -m 644 conf/dhclient.conf /etc/dhcp/dhclient.conf

        # amd64
    else

        ## TODO: update-me
        echo -e "${Red}ENABLE i386 ARCH${Color_Off}"
        dpkg --add-architecture i386

        echo -e "${Red}ADJUST GRUB${Color_Off}"
        install -C -g root -o root -m 644 conf/grub /etc/default/grub
        /usr/sbin/update-grub

        if [ "${VERSION_ID:-}" = "13" ] || [ "${VERSION_CODENAME:-}" = "trixie" ]; then
            echo -e "${Red}SET INITIAL APT SOURCES${Color_Off}"
            install -C -g root -o root -m 644 conf/apt/sources-13.list /etc/apt/sources.list
        fi

        echo -e "${Red}INSTALL GNUPG${Color_Off}"
        apt-get -y update
        apt-get -y dist-upgrade
        apt-get -y install gnupg

        echo -e "${Red}SET HERMES APT SOURCES${Color_Off}"
        if [ "${VERSION_ID:-}" = "13" ] || [ "${VERSION_CODENAME:-}" = "trixie" ]; then
            install -C -g root -o root -m 644 conf/apt/hermes-13_amd64.list /etc/apt/sources.list.d/hermes.list
            wget --no-check-certificate -qO- https://debian.hermes.radio/hermes/hermes.key | gpg --dearmor -o - > /etc/apt/trusted.gpg.d/hermes.gpg
        fi

        echo -e "${Red}RUN apt-get update / dist-upgrade${Color_Off}"
        apt-get -y update
        apt-get -y dist-upgrade

        echo -e "${Red}Installing npm${Color_Off}"
        apt-get -y install npm

        echo "postfix postfix/mailname string ${HERMES_HOSTNAME}" | debconf-set-selections
        echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections

        echo -e "${Red}INSTALLING PACKAGES${Color_Off}"
        if [ "${MODEM_TYPE}" = "vara" ]; then
            PACKAGES="${PACKAGES} \
            xvfb \
            x11vnc \
            tightvncpasswd \
            xserver-xorg \
            xinit
            wine \
            wine32 \
            wine64 \
            libwine \
            libwine:i386 \
            fonts-wine \
            libasound2-plugins:i386"
        fi

        echo -e "${Red}INSTALLING PACKAGES${Color_Off}"
        DEBIAN_FRONTEND=noninteractive apt-get -y install ${PACKAGES} firmware-realtek firmware-atheros

        echo -e "${Red}INSTALLING NESC${Color_Off}"
        dpkg -i conf/packages/nesc_0.2-2_amd64.deb

        if [ "${HERMES_HARDENING}" = "true" ]; then
            echo -e "${Red}SUDOERS: scoped policy for the web API${Color_Off}"
            install -C -g root -o root -m 440 conf/sudoers.d/hermes /etc/sudoers.d/hermes
            if command -v visudo > /dev/null; then
                visudo -c -f /etc/sudoers.d/hermes
            fi
            # undo the NOPASSWD line an earlier install may have left
            sed -i '/^%sudo/c\%sudo ALL=(ALL:ALL) ALL' /etc/sudoers
        else
            echo -e "${Red}SUDOERS NOPASSWD${Color_Off}"
            sed -i '/%sudo/c\%sudo ALL=(ALL) NOPASSWD: ALL' /etc/sudoers
        fi

        # only harden sshd when we ship keys, otherwise the station locks us out
        if [ "${HERMES_HARDENING}" = "true" ] && [ -s conf/ssh/authorized_keys ]; then
            echo -e "${Red}SSH: key-only access${Color_Off}"
            mkdir -p /etc/ssh/sshd_config.d
            install -C -g root -o root -m 644 conf/ssh/hermes.conf /etc/ssh/sshd_config.d/hermes.conf
            for admin_home in /root /home/pi; do
                mkdir -p "${admin_home}/.ssh"
                install -C -m 600 conf/ssh/authorized_keys "${admin_home}/.ssh/authorized_keys"
            done
            chown -R pi:pi /home/pi/.ssh
        else
            echo -e "${Red}SSH: password login stays enabled${Color_Off}"
        fi

        echo -e "${Red}www-data and uucp to sudo group${Color_Off}"
        usermod -a -G sudo www-data
        usermod -a -G sudo uucp
        usermod -a -G sudo hermes

    fi

}
