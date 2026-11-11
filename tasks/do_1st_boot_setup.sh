# to be read by another script


do_1st_boot_setup()
{
    cd ${INSTALLER_DIRECTORY}
    
    if [ "${HARDWARE}" = "sbitx" ] && [ "${virtual_env}" = false ]; then

        systemctl daemon-reload

        echo -e "${Red}HW CLOCK TO UTC${Color_Off}"
        timedatectl set-local-rtc 0

        echo -e "${Red}Setting 0.5% reserved space in root fs${Color_Off}"
        tune2fs -m 0.5 /dev/mmcblk0p2

        echo -e "${Red}Setting default EEPROM boot options${Color_Off}"
        rpi-eeprom-config -a conf/eeprom.cfg
        rpi-eeprom-update -a

        echo -e "${Red}Starting SSH${Color_Off}"
        systemctl start ssh

        echo -e "${Red}Restarting systemd-binfmt{Color_Off}"
        systemctl restart systemd-binfmt

        echo -e "${Red}Disabling getty on tty1${Color_Off}"
        systemctl stop getty@tty1.service

        set +e
        echo -e "${Red}Enabling OpenVPN${Color_Off}"
        systemctl start openvpn-client@${vpn_file_base}.service
        set -e

        echo -e "${Red}Enabling WiFi${Color_Off}"
        rfkill unblock wlan

        echo -e "${Red}Setting up WiFi Access Point${Color_Off}"
        systemctl start dnsmasq
        systemctl start hostapd

        echo -e "${Red}Starting UUCP${Color_Off}"
        systemctl start uucp.socket

        echo -e "${Red}Starting iWatch${Color_Off}"
        systemctl stop iwatch
        systemctl start iwatch

        echo -e "${Red}Starting NGINX${Color_Off}"
        systemctl stop nginx
        systemctl start nginx

        echo -e "${Red}Starting Email Subsystems${Color_Off}"
        systemctl start postfix
        systemctl start dovecot

        echo -e "DONE" > /root/hermes-setup-done.txt

    elif [ "${HARDWARE}" = "sbitx" ] && [ "${virtual_env}" = true ]; then

        # An image build (HERMES-tools image_installer.sh, under
        # systemd-nspawn). What the station needs before its first boot is
        # done here, in the image; what needs its Raspberry Pi runs once on
        # that first boot. (This used to be a script for a first boot under
        # QEMU, which the Raspberry Pi OS trixie kernel no longer completes.)

        echo -e "${Red}Image: 2 GB of swap, created by dphys-swapfile at boot${Color_Off}"
        echo "CONF_SWAPSIZE=2000" > /etc/dphys-swapfile

        echo -e "${Red}Image: WiFi unblocked${Color_Off}"
        # systemd-rfkill restores this at boot: 0 is unblocked, 1 blocked.
        # The name is the Pi 4's WiFi; the first boot unblocks any model.
        mkdir -p /var/lib/systemd/rfkill
        echo 0 > "/var/lib/systemd/rfkill/platform-fe300000.mmcnr:wlan"

        echo -e "${Red}Creating the first-boot setup for ${HARDWARE}${Color_Off}"
        # the installer is not in the image after the build
        install -D -m 644 conf/eeprom.cfg /usr/share/hermes/eeprom.cfg
        cat << 'EOF' > /usr/bin/hermes_installer.sh
#!/bin/bash
# HERMES: runs once, on the station's first boot on its Raspberry Pi.
echo "WiFi unblocked, for the access point"
rfkill unblock wlan || true
echo "HW clock to UTC"
timedatectl set-local-rtc 0
echo "0.5% reserved space in the root file system"
tune2fs -m 0.5 "$(findmnt -n -o SOURCE /)"
echo "Default EEPROM boot options"
rpi-eeprom-config -a /usr/share/hermes/eeprom.cfg
rpi-eeprom-update -a
if command -v wineboot > /dev/null; then
    echo "Wine prefix for VARA"
    HOME=/root wineboot
fi
systemctl disable hermes-1st-boot-setup.service
echo "DONE" > /root/hermes-setup-done.txt
EOF
        chmod +x /usr/bin/hermes_installer.sh

        cat << 'EOF' > /etc/systemd/system/hermes-1st-boot-setup.service
[Unit]
Description=HERMES first-boot setup (WiFi, EEPROM, root file system, Wine prefix)
After=local-fs.target
# VARA (x11.service) starts on the Wine prefix this makes, and the access
# point on the WiFi this unblocks
Before=x11.service hostapd.service dnsmasq.service
ConditionPathExists=!/root/hermes-setup-done.txt

[Service]
Type=oneshot
ExecStart=/usr/bin/hermes_installer.sh

[Install]
WantedBy=multi-user.target
EOF
        systemctl enable hermes-1st-boot-setup.service

        echo -e "${Red}First-boot setup created: it runs once, on the station's first boot${Color_Off}"
    else
        echo -e "${Red}No 1st boot setup required for ${HARDWARE} with virtual_env=${virtual_env}${Color_Off}"
    fi
}
