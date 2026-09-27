# to be read by the hermes-installer

do_certificate_setup()
{

    echo -e "${Red}Setting up SSL certificate and key${Color_Off}"

    # The certificate shipped in this repository (a *.hermes.radio one) is
    # shared by every station that installs it, and its private key is in
    # git; but browsers trust it, and the stations of deployed networks use
    # it. It stays the default; with HERMES_HARDENING the station generates
    # its own instead. TLS_SHARED_CERT in the station file overrides either.
    # A copy of the installer without the shared certificate's key (a public
    # one) makes each station's own.
    if [ "${HERMES_HARDENING}" = "true" ] || [ ! -s conf/ssl/hermes.radio/hermes.radio.key ]; then
        TLS_SHARED_CERT="${TLS_SHARED_CERT:-false}"
    else
        TLS_SHARED_CERT="${TLS_SHARED_CERT:-true}"
    fi

    if [ "${TLS_SHARED_CERT}" = "true" ]; then

        if [ -n "${SSL_DOMAIN+x}" ] && [ -s conf/ssl/${SSL_DOMAIN}/${SSL_DOMAIN}.key ]; then
            cert_dir="conf/ssl/${SSL_DOMAIN}"
            cert_name="${SSL_DOMAIN}"
        else
            cert_dir="conf/ssl/hermes.radio"
            cert_name="hermes.radio"
        fi

        echo -e "${Red}Using the certificate shipped for ${cert_name}${Color_Off}"

        # a station that generated its own before must not renew over this one
        set +e
        systemctl disable --now hermes-tls-renew.timer 2> /dev/null
        set -e

        install -C -g ssl-cert -o root -m 644 ${cert_dir}/${cert_name}.crt /etc/ssl/certs/hermes.radio.crt
        install -C -g ssl-cert -o root -m 640 ${cert_dir}/${cert_name}.key /etc/ssl/private/hermes.radio.key

        ## please remove the next 2 lines after we update websocket cert/key path in trx_v2-userland ##
        install -C -g ssl-cert -o root -m 640 ${cert_dir}/${cert_name}.crt /etc/ssl/private/hermes.radio.crt
        install -C -g ssl-cert -o root -m 640 ${cert_dir}/${cert_name}.key /etc/ssl/private/hermes.key

    else

        echo -e "${Red}Generating this station's own certificate${Color_Off}"

        install -C -g root -o root -m 755 conf/tls/hermes-tls-renew /usr/local/sbin/hermes-tls-renew
        install -C -g root -o root -m 644 conf/tls/hermes-tls-renew.service /lib/systemd/system/hermes-tls-renew.service
        install -C -g root -o root -m 644 conf/tls/hermes-tls-renew.timer /lib/systemd/system/hermes-tls-renew.timer

        HERMES_TLS_CN="${HERMES_HOSTNAME}" /usr/local/sbin/hermes-tls-renew --force

        set +e
        systemctl daemon-reload
        systemctl enable hermes-tls-renew.timer
        systemctl start hermes-tls-renew.timer
        set -e
    fi

    mkdir -p /etc/dovecot/ssl/
    ## We always hardcode the cert and key to hermes.radio.*

    rm -f /etc/dovecot/ssl/mailserver.key
    rm -f /etc/dovecot/ssl/mailserver.crt
    ln -s /etc/ssl/private/hermes.radio.key /etc/dovecot/ssl/mailserver.key
    ln -s /etc/ssl/certs/hermes.radio.crt /etc/dovecot/ssl/mailserver.crt

}
