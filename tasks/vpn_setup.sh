# to be called by hermes installer

do_vpn_setup()
{

    echo -e "${Red}VPN SETUP${Color_Off}"

    # The station's OpenVPN client configuration: VPN_CONFIG_FILE if the
    # station file (or the environment) names one, else conf/vpn/<station>.ovpn,
    # unpacked from conf/vpn/keys.tar.gz.gpg when a deployment keeps its
    # clients there (its passphrase in conf/vpn/passphrase).  No configuration
    # at all: the station gets no VPN client.
    local vpn_dir="${INSTALLER_DIRECTORY}/conf/vpn"
    if [ -s "${vpn_dir}/keys.tar.gz.gpg" ] && [ -s "${vpn_dir}/passphrase" ]; then
        (
            cd "${vpn_dir}"
            gpg -o keys.tar.gz -d --batch --pinentry-mode loopback \
                --passphrase-file passphrase --yes keys.tar.gz.gpg
            tar xf keys.tar.gz
        )
    fi

    local ovpn="${VPN_CONFIG_FILE:-${vpn_dir}/${vpn_file_base}.ovpn}"
    if [ ! -s "${ovpn}" ]; then
        echo -e "${Red}No VPN configuration for ${vpn_file_base} (${ovpn}): no VPN client${Color_Off}"
        cd ${INSTALLER_DIRECTORY}
        return 0
    fi

    cp "${ovpn}" /etc/openvpn/client/${vpn_file_base}.conf

    cd /lib/systemd/system/
    ln -sf /lib/systemd/system/openvpn-client@.service openvpn-client@${vpn_file_base}.service
    cd -

    systemctl enable openvpn-client@${vpn_file_base}.service

    # A station reinstalled under another name (estacao3 turned into the
    # gateway estacao, say) still has its old name's client enabled: two
    # tunnels, two addresses.  Switch that one off (its files stay), and only
    # when the name changes: a reinstall under the same name leaves every
    # client as it was.
    if [ -n "${ORIGINAL_HOSTNAME:-}" ] && [ "${ORIGINAL_HOSTNAME}" != "${HERMES_HOSTNAME}" ] \
       && [ "${ORIGINAL_HOSTNAME}" != "${vpn_file_base}" ]; then
        set +e
        if systemctl is-enabled --quiet "openvpn-client@${ORIGINAL_HOSTNAME}.service" 2> /dev/null; then
            echo -e "${Red}Disabling openvpn-client@${ORIGINAL_HOSTNAME}, this station's VPN client under its old name${Color_Off}"
            systemctl disable --now "openvpn-client@${ORIGINAL_HOSTNAME}.service"
        fi
        set -e
    fi

    cd ${INSTALLER_DIRECTORY}
}
