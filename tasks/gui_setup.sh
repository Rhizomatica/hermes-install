# to be read in hermes-installer

do_gui_install()
{

    echo -e "${Red}INSTALLING HERMES-GUI${Color_Off}"

    # # Install/load nvm (avoids conflicts with any pre-existing system Node version)
    # export NVM_DIR="/root/.nvm"
    # if [ ! -s "${NVM_DIR}/nvm.sh" ]; then
    #     curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    # fi
    # \. "${NVM_DIR}/nvm.sh"

    # if [ "${VERSION_ID:-}" = "13" ]; then
    #     nvm install 20.20.0  # Debian 13 (trixie): Angular 18
    #     nvm use 20.20.0
    #     npm install -g npm@11.9.0
    # else
    #     nvm install 18.17.1  # Debian 12 (bookworm): Angular 14
    #     nvm use 18.17.1
    #     npm install -g npm@10.8.2
    # fi

    mkdir -p ${TMP_PATH}
    cd ${TMP_PATH}
    rm -rf hermes-gui
    git clone https://github.com/Rhizomatica/hermes-gui
    cd hermes-gui/

    if [ "${VERSION_ID:-}" = "13" ]; then
        if [ ${HERMES_PRODUCTION} = "false" ]; then
            git fetch
            git checkout development
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
        echo "PRODUCTION=${HERMES_PRODUCTION}"
        echo "HAS_GPS=${HAS_GPS:-false}"
        echo "GPS_MAP=${GPS_MAP:-bangladesh}"
        echo "GATEWAY=$( [ "${HERMES_ROLE}" = "gateway" ] && echo true || echo false )"
        echo "BITX=$( [ "${HARDWARE}" = "sbitx" ] && echo S || echo U )"
        echo "REQUIRE_LOGIN=${REQUIRE_LOGIN}"
        echo "EMERGENCY_EMAIL=${EMERGENCY_EMAIL:-emergency@hermes.radio}"
        echo "LOCALE_ID=${HERMES_LANGUAGE:-en-US}"
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
