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

        echo -e "${Red}Creating 1st boot setup script for ${HARDWARE} in virtual_env${Color_Off}"
        cat << 'EOF' > /usr/bin/hermes_installer.sh
#!/bin/bash
# run me as root!
if [[ $(id -u) -ne 0 ]];
then
    echo "Please run as root";
    exit 1;
fi
echo -e "${Red}Setting up 2GB of swap(file)${Color_Off}"
echo "CONF_SWAPSIZE=2000" > /etc/dphys-swapfile
dphys-swapfile swapoff
dphys-swapfile setup
# dphys-swapfile swapon

echo -e "${Red}HW CLOCK TO UTC${Color_Off}"
timedatectl set-local-rtc 0

echo -e "${Red}Setting 0.5% reserved space in root fs${Color_Off}"
# qemu for some reason uses /dev/mmcblk1p2 instead of /dev/mmcblk0p2
tune2fs -m 0.5 /dev/mmcblk1p2

set +e
echo -e "${Red}Enabling WiFi${Color_Off}"
# rfkill unblock wlan
echo 1 > "/var/lib/systemd/rfkill/platform-fe300000.mmcnr:wlan"

echo -e "${Red}Setting default EEPROM boot options${Color_Off}"
rpi-eeprom-config -a /root/hermes-installer/conf/eeprom.cfg
rpi-eeprom-update -a
set -e

echo -e "${Red}Removing the installer${Color_Off}"
rm -rf /root/hermes-installer /root/hermes-installer.tar.gz
rm -rf /root/install

echo -e "${Red}Running apt-get cleanup${Color_Off}"
apt-get clean

#echo -e "${Red}Removing hermes-1st-boot-setup.sh script${Color_Off}"
# rm -f /usr/bin/hermes_installer.sh

echo -e "${Red}1st boot setup for ${HARDWARE} in virtual_env done. Waiting a bit for other 1st boot tasks to finish...${Color_Off}"
i=0
while [ $i -lt 40 ]; do
    echo -ne "[*] HERMES Installer waiting... $i\r"
    sleep 1
    i=$((i+1))
done

echo -e "${Red}Removing hermes-1st-boot-setup.service${Color_Off}"
systemctl disable hermes-1st-boot-setup.service

echo -e "DONE" > /root/hermes-setup-done.txt
shutdown -h now
EOF
        chmod +x /usr/bin/hermes_installer.sh

        # create a systemd service to run the script on 1st boot
        cat << 'EOF' > /etc/systemd/system/hermes-1st-boot-setup.service
[Unit]
Description=Hermes 1st Boot Setup
After=sysinit.target
Before=sbitx.service
[Service]
Type=oneshot
# RemainAfterExit=yes
ExecStart=/usr/bin/hermes_installer.sh
StandardInput=tty-force
StandardOutput=inherit
StandardError=inherit

[Install]
WantedBy=multi-user.target
EOF
        # enable the service
        systemctl enable hermes-1st-boot-setup.service

        echo -e "${Red}1st boot setup script for ${HARDWARE} in virtual_env created. It will run on next boot.${Color_Off}"
    else
        echo -e "${Red}No 1st boot setup required for ${HARDWARE} with virtual_env=${virtual_env}${Color_Off}"
    fi
}
