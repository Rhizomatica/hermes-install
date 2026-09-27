# to be read in hermes-installer

do_gui_install()
{

    echo -e "${Red}INSTALLING HERMES-GUI${Color_Off}"

    mkdir -p ${TMP_PATH}
    cd ${TMP_PATH}
    rm -rf hermes-gui
    git clone https://github.com/Rhizomatica/hermes-gui
    cd hermes-gui/

    if [ "${VERSION_ID:-}" = "13" ]; then
        if [ -n "${HERMES_GUI_BRANCH:-}" ]; then
            git fetch
            git checkout "${HERMES_GUI_BRANCH}"
        fi
        npm install -g @angular/cli@18.2.21 --legacy-peer-deps --force
    else
        git checkout debian-12-compat
        npm install -g @angular/cli@14.2.12 --legacy-peer-deps --force
    fi

    npm install --legacy-peer-deps

    # Write .env file for the GUI setup
    {
        echo "DOMAIN=${HERMES_HOSTNAME}"
        echo "LOCAL=false"
        echo "PRODUCTION=true"
        echo "HAS_GPS=${HAS_GPS:-false}"
        echo "GPS_MAP=${GPS_MAP:-bangladesh}"
        echo "GATEWAY=$( [ "${HERMES_ROLE}" = "gateway" ] && echo true || echo false )"
        echo "BITX=$( [ "${HARDWARE}" = "sbitx" ] || [ "${HARDWARE}" = "hamlib" ] && echo S || echo U )"
        echo "REQUIRE_LOGIN=${REQUIRE_LOGIN}"
        echo "EMERGENCY_EMAIL=${EMERGENCY_EMAIL:-emergency@hermes.radio}"
        echo "LOCALE_ID=${HERMES_LANGUAGE:-en-US}"
        echo "RADIO_DAEMON=${HERMES_DAEMON:-$( [ "${RADIO_CONTROLLER}" = "radiod" ] && echo true || echo false )}"

    } >> .env

    npx --yes ts-node setEnv.ts

    export NODE_OPTIONS="--max_old_space_size=4096"
    export NG_FORCE_TTY="false"

    rm -rf dist/

    if [ "${VERSION_ID:-}" = "13" ]; then
        # Debian 13: Angular 18 application builder, locales under dist/hermes/browser/
        npm run build-prod
        cp -a dist/hermes/browser/* /var/www/html/
    else
        # Debian 12: Angular 14 browser builder, locales under dist/hermes/
        ng build --configuration production
        cp -a dist/hermes/* /var/www/html/
    fi

    chown -R www-data:www-data /var/www/html/

}
