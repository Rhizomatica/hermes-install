# to be called by hermes installer

do_vpn_setup()
{

    echo -e "${Red}VPN SETUP${Color_Off}"

    # place your keys in the format "hostname.ovpn", for eg., station1.hermes.radio.ovpn
    cp ${INSTALLER_DIRECTORY}/conf/vpn/${vpn_file_base}.ovpn /etc/openvpn/client/${vpn_file_base}.conf

    cd /lib/systemd/system/
    ln -sf /lib/systemd/system/openvpn-client@.service openvpn-client@${vpn_file_base}.service
    cd -

    systemctl enable openvpn-client@${vpn_file_base}.service
    systemctl start openvpn-client@${vpn_file_base}.service

    cd ${INSTALLER_DIRECTORY}
}
