# read by hermes installer

do_network_setup()
{

    echo -e "${Red}SETTING NETWORK CONFIG INTERFACE${Color_Off}"
    rm -f /etc/network/interfaces.d/*

    install -C -g root -o root -m 644 conf/eth0 /etc/network/interfaces.d/eth0
    install -C -g root -o root -m 644 conf/wlan0 /etc/network/interfaces.d/wlan0

    rfkill unblock wlan

    # TODO DNSMASQ!
    # Please set the records for the SSL cert to work, and also set the MX records
    # https://www.onderka.com/computer-und-netzwerk/autoritativer-dns-server-mit-dnsmasq
    # and set #IGNORE_SYSTEMD_RESOLVED in the "defaults" file for dnsmasq
    # https://gist.github.com/frank-dspeed/6b6f1f720dd5e1c57eec8f1fdb2276df
    echo -e "${Red}SET DNSMASQ CONF${Color_Off}"
    install -C -g root -o root -m 644 conf/dnsmasq.conf /etc/dnsmasq.conf
    domain_name=${station_name}
    echo "address=/.${domain_name}/10.0.0.1" >> /etc/dnsmasq.conf
    systemctl unmask dnsmasq
    systemctl enable dnsmasq
    systemctl start dnsmasq

    echo -e "${Red}SET HOSTAPD CONF${Color_Off}"
    install -C -g root -o root -m 644 conf/hostapd.conf /etc/hostapd/hostapd.conf
    install -C -g root -o root -m 644 conf/hostapd.conf.head /etc/hostapd/hostapd.conf.head
    touch /etc/hostapd/accept

    systemctl unmask hostapd
    systemctl enable hostapd
    systemctl start hostapd


}
