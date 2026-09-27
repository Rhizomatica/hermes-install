# to be read by hermes installer
#
# Per-station secrets. Generated once on the station, kept in
# /etc/hermes/secrets (root, 0600) and reused by later installs, so the
# passwords are never the same on two stations and never live in this
# repository.
#
# Without HERMES_HARDENING, and where conf/legacy-credentials exists, the
# file holds the historical defaults from there instead, which the stations
# of deployed networks and their operators rely on. Turning HERMES_HARDENING
# on later replaces those with random ones; a file that already holds random
# passwords is never replaced, since services on the station already use
# them. Without conf/legacy-credentials the passwords are always random.
#
# Every task that needs a password sources this file through the installer.

SECRETS_FILE="${SECRETS_FILE:-/etc/hermes/secrets}"

# a password safe to paste in configuration files and URLs
gen_password()
{
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "${1:-24}"
}

do_secrets_setup()
{

    echo -e "${Red}STATION SECRETS${Color_Off}"

    mkdir -p "$(dirname "${SECRETS_FILE}")"
    chmod 700 "$(dirname "${SECRETS_FILE}")"

    if [ "${HERMES_HARDENING}" = "true" ] && [ -s "${SECRETS_FILE}" ] \
       && grep -q '^HERMES_SECRETS_LEGACY="true"' "${SECRETS_FILE}"; then
        echo -e "${Red}HERMES_HARDENING: replacing the default passwords${Color_Off}"
        mv "${SECRETS_FILE}" "${SECRETS_FILE}.legacy"
    fi

    # The historical defaults live in conf/legacy-credentials, which only
    # the deployments that need them have; without it, the passwords are
    # random, as with HERMES_HARDENING.
    local legacy="${INSTALLER_DIRECTORY}/conf/legacy-credentials"
    if [ ! -s "${SECRETS_FILE}" ] && [ "${HERMES_HARDENING}" != "true" ] && [ -s "${legacy}" ]; then
        echo -e "${Red}Writing the default passwords to ${SECRETS_FILE}${Color_Off}"

        umask 077
        {
            echo "# HERMES station secrets: the historical defaults, written $(date -u +%Y-%m-%dT%H:%M:%SZ)"
            echo '# Set HERMES_HARDENING="true" in the station file for random ones.'
            echo 'HERMES_SECRETS_LEGACY="true"'
            grep -E '^(HERMES_DB_PASSWORD|ROUNDCUBE_DB_PASSWORD|ROUNDCUBE_DES_KEY|MAIL_ROOT_PASSWORD|HERMES_EMAILAPI_PASS|VNC_PASSWORD|PI_PASSWORD|WIFI_PASSPHRASE)=' "${legacy}"
            echo "API_APP_KEY='$(date | openssl passwd -6 -stdin)'"
        } > "${SECRETS_FILE}"
    fi

    if [ ! -s "${SECRETS_FILE}" ]; then
        echo -e "${Red}Generating ${SECRETS_FILE}${Color_Off}"

        umask 077
        cat > "${SECRETS_FILE}" << EOF
# HERMES station secrets, generated $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Keep this file. Losing it means reinstalling the services that use it.
HERMES_DB_PASSWORD="$(gen_password 24)"
ROUNDCUBE_DB_PASSWORD="$(gen_password 24)"
# roundcube encrypts the IMAP password in the session with this key
ROUNDCUBE_DES_KEY="$(gen_password 24)"
MAIL_ROOT_PASSWORD="$(gen_password 16)"
HERMES_EMAILAPI_PASS="$(gen_password 24)"
VNC_PASSWORD="$(gen_password 8)"
PI_PASSWORD="$(gen_password 16)"
WIFI_PASSPHRASE="$(gen_password 12)"
API_APP_KEY="$(openssl rand -base64 32)"
EOF
    fi

    chown root:root "${SECRETS_FILE}"
    chmod 600 "${SECRETS_FILE}"

    . "${SECRETS_FILE}"
    hermes_legacy_credentials

    [ "${HERMES_SECRETS_LEGACY:-false}" = "true" ] && return 0
    # the historical pi and WiFi passwords are in effect: nothing new to tell
    [ "${HERMES_HARDENING}" != "true" ] && [ -s "${legacy}" ] && return 0

    # the admin needs the WiFi passphrase and the pi password at least once
    echo -e "${Red}WiFi passphrase: ${WIFI_PASSPHRASE}${Color_Off}"
    echo -e "${Red}pi password: ${PI_PASSWORD}${Color_Off}"
    echo -e "${Red}(also in ${SECRETS_FILE})${Color_Off}"

}
