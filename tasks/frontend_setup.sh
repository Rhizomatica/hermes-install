# to be read in hermes-installer

do_frontend_setup()
{

    echo -e "${Red}INSTALLING HERMES-FRONTEND${Color_Off}"

    # hermes-frontend is a Next.js monorepo and needs Node.js >= 20.9.
    # Use nvm so we don't clash with the distro's older nodejs/npm.
    export NVM_DIR="/root/.nvm"
    if [ ! -s "${NVM_DIR}/nvm.sh" ]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    fi
    \. "${NVM_DIR}/nvm.sh"
    nvm install 20.20.0
    nvm use 20.20.0
    npm install -g npm@11.9.0

    mkdir -p ${TMP_PATH}
    cd ${TMP_PATH}
    rm -rf hermes-frontend
    git clone https://github.com/Rhizomatica/hermes-frontend
    cd hermes-frontend/

    if [ "${HERMES_PRODUCTION}" = "false" ]; then
        git fetch
        git checkout development
    fi

    npm install --legacy-peer-deps

    # Choose which apps to install. Supported values (override per station with
    # HERMES_FRONTEND_APPS in the station file):
    #   all    -> shell + gps + chat (co-deployed, base paths /, /gps, /chat)
    #   gps    -> hermes-gps-final only (standalone, served at /)
    #   chat   -> hermes-chat-final only (standalone, served at /)
    #   shell  -> hermes-shell only
    case "${HERMES_FRONTEND_APPS:-all}" in
        chat)
            FRONTEND_APPS="hermes-chat-final:"
            ;;
        gps)
            FRONTEND_APPS="hermes-gps-final:"
            ;;
        shell)
            FRONTEND_APPS="hermes-shell:"
            ;;
        all|*)
            FRONTEND_APPS="hermes-shell: hermes-gps-final:/gps hermes-chat-final:/chat"
            ;;
    esac

    for entry in ${FRONTEND_APPS}; do
        app_name="${entry%%:*}"
        base_path="${entry#*:}"

        {
            echo "HERMES_API_URL=https://${HERMES_HOSTNAME}/api"
            echo "NEXT_PUBLIC_BASE_PATH=${base_path}"
            echo "NEXT_PUBLIC_SHELL_URL=https://${HERMES_HOSTNAME}"
            echo "NEXT_PUBLIC_LOGIN_URL=/login"
            echo "NEXT_PUBLIC_APP_VERSION=dev"
            echo "NEXT_PUBLIC_APP_TIME_ZONE=${TIMEZONE}"
            echo "NEXT_PUBLIC_PMTILES_URL=/brazil.pmtiles"
            echo "NEXT_PUBLIC_RADIO_DAEMON_WS_URL=ws://localhost:8081"
        } > apps/${app_name}/.env.local
    done

    export NODE_OPTIONS="--max_old_space_size=4096"

    # Build only the selected apps (turbo also builds their shared package deps)
    for entry in ${FRONTEND_APPS}; do
        app_name="${entry%%:*}"
        npx --yes turbo run build --filter=${app_name}
    done

    # Deploy the built monorepo. The apps are run with "next start" (standalone
    # output is not enabled yet), so keep the whole workspace + node_modules;
    # only the selected apps above get a .env.local and a build output.
    mkdir -p /opt/hermes-frontend
    cp -rT . /opt/hermes-frontend/

}
