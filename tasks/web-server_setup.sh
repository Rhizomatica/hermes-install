# to be read by the hermes-installer

do_webserver_setup()
{

    echo -e "${Red}WEB-SERVER SETUP${Color_Off}"

    install -C -g root -o root -m 644 conf/web/php.ini /etc/php/8.2/fpm/php.ini

    # TODO: make default language based on env var...
    install -C -g root -o root -m 644 conf/web/hermes.conf /etc/nginx/sites-available/hermes.conf

    if [ "${HERMES_LANGUAGE}" = "en" ]; then
        sed -i "s/HERMESLANGNGINX/en-US/g" /etc/nginx/sites-available/hermes.conf
    else
        sed -i "s/HERMESLANGNGINX/${HERMES_LANGUAGE}/g" /etc/nginx/sites-available/hermes.conf
    fi

    ln -sf /etc/nginx/sites-available/hermes.conf /etc/nginx/sites-enabled/01-hermes.conf

    rm -f /etc/nginx/sites-enabled/default

    systemctl enable nginx
    systemctl stop nginx
    systemctl start nginx

}
