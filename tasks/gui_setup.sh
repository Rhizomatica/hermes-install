# to be read in hermes-installer

do_gui_install()
{

    echo -e "${Red}INSTALLING HERMES-GUI${Color_Off}"

    mkdir -p ${TMP_PATH}
    cd ${TMP_PATH}
    rm -rf hermes-gui
    git clone https://github.com/Rhizomatica/hermes-gui
    cd hermes-gui/
    
    if [ ${HERMES_PRODUCTION} = "false" ]; then
        git fetch
        git checkout development
    fi
    
    npm install --legacy-peer-deps
    npm install -g @angular/cli@14.2.12 --legacy-peer-deps

    # should we allows some other option here tru "if"?
    echo "LOCAL=false" >> .env

    if [ "${HERMES_PRODUCTION}" = "true" ]; then
        echo "PRODUCTION=true" >> .env
    else
        echo "PRODUCTION=false" >> .env
    fi    

    if [ -n "${HAS_GPS+x}" ]; then
        if [ "${HAS_GPS}" = "true" ]; then
            echo "HAS_GPS=true" >> .env
        else
            echo "HAS_GPS=false" >> .env
        fi
    else
        echo "HAS_GPS=false" >> .env
    fi

    if [ -n "${GPS_MAP+x}" ]; then
            echo "GPS_MAP=${GPS_MAP}" >> .env
    else
        echo "GPS_MAP=bangladesh" >> .env
    fi

    echo "DOMAIN=${HERMES_HOSTNAME}" >> .env

    if [ ${HERMES_ROLE} = "gateway" ]; then
        echo "GATEWAY=true" >> .env
    else
        echo "GATEWAY=false" >> .env
    fi

    if [ ${HARDWARE} = "sbitx" ]; then
        echo "BITX=S" >> .env
    else
        echo "BITX=U" >> .env
    fi

    if [ ${REQUIRE_LOGIN} = "true" ]; then
        echo "REQUIRE_LOGIN=true" >> .env
    else
        echo "REQUIRE_LOGIN=false" >> .env
    fi

    if [ ${EMERGENCY_EMAIL} = "" ]; then
        echo "EMERGENCY_EMAIL=emergency@hermes.radio" >> .env
    else
        echo "EMERGENCY_EMAIL=${EMERGENCY_EMAIL}" >> .env
    fi

    npx ts-node setEnv.ts
    rm -rf dist/
    NG_FORCE_TTY=false ng build --configuration production
    cp -a dist/hermes/en-US/ /var/www/html/
    cp -a dist/hermes/pt/ /var/www/html/
    cp -a dist/hermes/es/ /var/www/html/
    cp -a dist/hermes/fr/ /var/www/html/

    chown -R www-data:www-data /var/www/html/

}
