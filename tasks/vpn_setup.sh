# to be called by hermes installer

do_vpn_setup()
{

    echo -e "${Red}VPN SETUP${Color_Off}"

    
    vpn_file_base=$(basename ${VPN_CONFIG_FILE} .ovpn)

    cp ${INSTALLER_DIRECTORY}/conf/vpn/${vpn_file_base}.ovpn /etc/openvpn/client/${vpn_file_base}.conf

    cd /lib/systemd/system/
    ln -sf /lib/systemd/system/openvpn-client@.service openvpn-client@${vpn_file_base}.service
    cd -

    systemctl enable openvpn-client@${vpn_file_base}.service

    cd ${INSTALLER_DIRECTORY}
}
