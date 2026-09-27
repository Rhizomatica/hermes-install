# to be read by the hermes-installer

do_webserver_setup()
{

    echo -e "${Red}WEB-SERVER SETUP${Color_Off}"

    if [ "${VERSION_ID:-}" = "13" ]; then
        install -C -g root -o root -m 644 conf/web/php.ini /etc/php/8.4/fpm/php.ini
    else
        install -C -g root -o root -m 644 conf/web/php.ini /etc/php/8.2/fpm/php.ini
    fi

    # TODO: make default language based on env var...
    install -C -g root -o root -m 644 conf/web/hermes.conf /etc/nginx/sites-available/hermes.conf

    if [ "${HERMES_LANGUAGE}" = "en" ]; then
        sed -i "s/HERMESLANGNGINX/en-US/g" /etc/nginx/sites-available/hermes.conf
    else
        sed -i "s/HERMESLANGNGINX/${HERMES_LANGUAGE}/g" /etc/nginx/sites-available/hermes.conf
    fi

    # Without HERMES_HARDENING: no cipher restriction and no HSTS/CSP headers,
    # as on the stations already deployed. HSTS in particular would make a
    # browser refuse the station for months once its certificate changes.
    if [ "${HERMES_HARDENING}" != "true" ]; then
        sed -i '/# BEGIN HERMES_HARDENING/,/# END HERMES_HARDENING/d' /etc/nginx/sites-available/hermes.conf
    fi

    ln -sf /etc/nginx/sites-available/hermes.conf /etc/nginx/sites-enabled/01-hermes.conf

    rm -f /etc/nginx/sites-enabled/default

    systemctl enable nginx

}
