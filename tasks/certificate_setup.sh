# to be read by the hermes-installer

do_certificate_setup()
{

    echo -e "${Red}Setting up SSL certificate and key${Color_Off}"

    if [ -n "${SSL_DOMAIN+x}" ]; then
        install -C -g ssl-cert -o root -m 644 conf/ssl/${SSL_DOMAIN}/${SSL_DOMAIN}.crt /etc/ssl/certs/hermes.radio.crt
        install -C -g ssl-cert -o root -m 640 conf/ssl/${SSL_DOMAIN}/${SSL_DOMAIN}.key /etc/ssl/private/hermes.radio.key

        ## please remove the next 2 lines after we update websocket cert/key path in trx_v2-userland ##
        install -C -g ssl-cert -o root -m 640 conf/ssl/${SSL_DOMAIN}/${SSL_DOMAIN}.crt /etc/ssl/private/hermes.radio.crt
        install -C -g ssl-cert -o root -m 640 conf/ssl/${SSL_DOMAIN}/${SSL_DOMAIN}.key /etc/ssl/private/hermes.key


    else  # SSL_DOMAIN should always be set... we can remove all this "else" at some point...
        install -C -g ssl-cert -o root -m 644 conf/ssl/hermes.radio/hermes.radio.crt /etc/ssl/certs/hermes.radio.crt
        install -C -g ssl-cert -o root -m 640 conf/ssl/hermes.radio/hermes.radio.key /etc/ssl/private/hermes.radio.key

        ## please remove the next 2 lines after we update websocket cert/key path in trx_v2-userland ##
        install -C -g ssl-cert -o root -m 640 conf/ssl/hermes.radio/hermes.radio.crt /etc/ssl/private/hermes.radio.crt
        install -C -g ssl-cert -o root -m 640 conf/ssl/hermes.radio/hermes.radio.key /etc/ssl/private/hermes.key
    fi

    mkdir -p /etc/dovecot/ssl/
    ## We always hardcode the cert and key to hermes.radio.*

    rm -f /etc/dovecot/ssl/mailserver.key
    rm -f /etc/dovecot/ssl/mailserver.crt
    ln -s /etc/ssl/private/hermes.radio.key /etc/dovecot/ssl/mailserver.key
    ln -s /etc/ssl/certs/hermes.radio.crt /etc/dovecot/ssl/mailserver.crt

}
