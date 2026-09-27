# to be read in hermes-installer

do_backend_setup()
{

    echo -e "${Red}INSTALLING HERMES-BACKEND${Color_Off}"

    # hermes-backend requires Node.js >= 20.19.0. Use nvm so we don't clash
    # with the distro's older nodejs/npm (18 on bookworm, 20 on trixie).
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
    rm -rf hermes-backend
    git clone https://github.com/Rhizomatica/hermes-backend
    cd hermes-backend/

    if [ "${HERMES_PRODUCTION}" = "false" ]; then
        git fetch
        git checkout development
    fi

    npm install

    npm run build

    # Write .env file for the backend setup (keys read by src/shared/config.ts)
    {
        echo "DATABASE_PATH=./data/hermes.sqlite"
        echo "PORT=3000"
        echo "HOST=0.0.0.0"
        echo "LOG_LEVEL=info"
        echo "CORS_ORIGINS=*"
        echo "RADIO_DRIVER=$( [ "${HARDWARE}" = "sbitx" ] || [ "${HARDWARE}" = "hamlib" ] && echo sbitx || echo simulated )"
        echo "DB_ADAPTER=sqlite"
        echo "JWT_PRIVATE_KEY_PATH=./keys/private.pem"
        echo "JWT_PUBLIC_KEY_PATH=./keys/public.pem"
        echo "JWT_ACCESS_EXPIRES_IN=900"
        echo "JWT_REFRESH_EXPIRES_IN=604800"
    } > .env

    # JWT RS256 keypair
    mkdir -p keys
    openssl genrsa -out keys/private.pem 2048
    openssl rsa -in keys/private.pem -pubout -out keys/public.pem
    chmod 600 keys/private.pem

    # Data directories
    mkdir -p data/attachments data/keys certs logs

    # Deploy to /opt/hermes-backend
    mkdir -p /opt/hermes-backend
    cp -rT . /opt/hermes-backend/

    cd /opt/hermes-backend/
    npm run db:migrate
    cd -

}
