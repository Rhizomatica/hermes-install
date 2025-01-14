# to be read by other script

do_vpn_wireguard_setup()
{

    echo -e "${Red}WIREGUARD VPN SETUP${Color_Off}"

    set +e

    cp ${INSTALLER_DIRECTORY}/conf/vpn/${HERMES_HOSTNAME}.conf /etc/wireguard/wg0.conf
    chmod 640 /etc/wireguard/wg0.conf

    systemctl disable wg-quick@wg0
    systemctl enable wg-quick@wg0
    systemctl start wg-quick@wg0

    set -e
}
