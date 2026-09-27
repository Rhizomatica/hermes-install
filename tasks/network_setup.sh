# read by hermes installer

do_network_setup()
{

    echo -e "${Red}SETTING NETWORK CONFIG INTERFACE${Color_Off}"
    rm -f /etc/network/interfaces.d/*

    install -C -g root -o root -m 644 conf/eth0 /etc/network/interfaces.d/eth0
    install -C -g root -o root -m 644 conf/wlan0 /etc/network/interfaces.d/wlan0

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

    echo -e "${Red}SET HOSTAPD CONF${Color_Off}"
    # The web interface reads hostapd.conf (GET /api/wifi runs as www-data):
    # world-readable as it always was, and with HERMES_HARDENING readable by
    # www-data only, since it holds the WiFi passphrase.  (Mode 600 broke the
    # WiFi settings page on every station installed since 2026-09-16.)
    if [ "${HERMES_HARDENING}" = "true" ]; then
        install -C -g www-data -o root -m 640 conf/hostapd.conf /etc/hostapd/hostapd.conf
    else
        install -C -g root -o root -m 644 conf/hostapd.conf /etc/hostapd/hostapd.conf
    fi
    install -C -g root -o root -m 644 conf/hostapd.conf.head /etc/hostapd/hostapd.conf.head
    touch /etc/hostapd/accept

    # Without HERMES_HARDENING, the WiFi of the stations already deployed:
    # WPA and WPA2 with TKIP, which the older phones in the field may need.
    if [ "${HERMES_HARDENING}" != "true" ]; then
        for f in /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.head; do
            sed -i -e 's/^wpa=2$/wpa=3/' \
                   -e 's/^wpa_key_mgmt=WPA-PSK SAE$/wpa_key_mgmt=WPA-PSK\nwpa_pairwise=TKIP/' \
                   -e '/^ieee80211w=1$/d' -e '/^# WPA3-SAE where/d' "${f}"
        done
    fi

    # this station's own WiFi passphrase, from /etc/hermes/secrets
    if [ -n "${WIFI_PASSPHRASE:-}" ]; then
        sed -i "s/WIFI_PASSPHRASE/${WIFI_PASSPHRASE}/" /etc/hostapd/hostapd.conf
    fi

    systemctl unmask hostapd
    systemctl enable hostapd

}
