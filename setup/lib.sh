# Station files and network files, for hermes-setup.
#
# A station file (stations/<hostname>) is the shell fragment the installer
# sources.  A network (UUCP_NET) is three files in conf/:
#   sys-gw.<net>     the gateway's /etc/uucp/sys: the central server over the
#                    VPN ("system hermes", alias gw), the gateway itself
#                    (alias local) and every remote station
#   sys.<net>        a remote station's /etc/uucp/sys: the gateway (alias gw)
#                    and every remote station; the installer renames the
#                    station's own alias to "local"
#   transport.<net>  the gateway's Postfix transport map: each remote
#                    station's domain to its UUCP alias
#
# Nothing here draws a screen, so that it can be tested on its own.

# Every setting a station file can hold, in the order hermes-setup writes
# them.  Settings a station file has that are not listed here are kept, at
# the end of the file.
STATION_VARS="HERMES_HOSTNAME CALLSIGN UUCP_ALIAS UUCP_NET HERMES_ROLE \
HERMES_LANGUAGE TIMEZONE SSL_DOMAIN EMERGENCY_EMAIL HERMES_FWD_EMAIL \
HARDWARE RADIO_CONTROLLER DISPLAY_TYPE DIGITAL_VOICE_CODEC \
RIG_MODEL RIG_DEVICE RIG_SERIAL_RATE RIG_PTT_TYPE RIG_AUDIO_DEVICE \
SOUND_CARD INSTALL_FIRMWARE RADUINO_VER \
MODEM_TYPE VARA_KEY NNCP_ENABLED UUCP_PRE_AGREED \
HAS_GPS GPS_MAP REQUIRE_LOGIN HERMES_HARDENING MAIL_ENCRYPTION \
DEFAULT_VOICE DEFAULT_DATA_FREQUENCY DEFAULT_DATA_MODE \
DEFAULT_VOICE_FREQUENCY DEFAULT_VOICE_MODE"

# Defaults for a new station.
station_defaults()
{
    HERMES_HOSTNAME=""
    CALLSIGN=""
    UUCP_ALIAS=""
    UUCP_NET=""
    HERMES_ROLE="remote"
    HERMES_LANGUAGE="en"
    TIMEZONE="America/Sao_Paulo"
    SSL_DOMAIN="hermes.radio"
    EMERGENCY_EMAIL="emergency@hermes.radio"
    HERMES_FWD_EMAIL=""
    HARDWARE="sbitx"
    RADIO_CONTROLLER="radiod"
    DISPLAY_TYPE="v2"
    DIGITAL_VOICE_CODEC="radev2"
    RIG_MODEL=""
    RIG_DEVICE="/dev/ttyUSB0"
    RIG_SERIAL_RATE="19200"
    RIG_PTT_TYPE="RIG"
    RIG_AUDIO_DEVICE="hw:CODEC,0"
    SOUND_CARD=""
    INSTALL_FIRMWARE="0"
    RADUINO_VER="1"
    MODEM_TYPE="mercury"
    VARA_KEY=""
    NNCP_ENABLED="false"
    UUCP_PRE_AGREED="true"
    HAS_GPS="false"
    GPS_MAP=""
    REQUIRE_LOGIN="false"
    HERMES_HARDENING="false"
    MAIL_ENCRYPTION="true"
    DEFAULT_VOICE="false"
    DEFAULT_DATA_FREQUENCY="7480000"
    DEFAULT_DATA_MODE="USB"
    DEFAULT_VOICE_FREQUENCY="7480000"
    DEFAULT_VOICE_MODE="USB"
    STATION_EXTRA=""
}

# What the installer assumes for a setting a station file leaves out (see
# common.sh): an existing file must mean the same thing once rewritten.  No
# frequency or mode means the radio's profiles are left as they are.
station_installer_defaults()
{
    local v

    for v in ${STATION_VARS}; do
        printf -v "${v}" '%s' ""
    done
    MODEM_TYPE="vara"
    DISPLAY_TYPE="v1"
    RIG_DEVICE="/dev/ttyUSB0"
    RIG_SERIAL_RATE="19200"
    RIG_PTT_TYPE="RIG"
    RIG_AUDIO_DEVICE="hw:CODEC,0"
    NNCP_ENABLED="false"
    UUCP_PRE_AGREED="false"
    HAS_GPS="false"
    HERMES_HARDENING="false"
    MAIL_ENCRYPTION="true"
    DEFAULT_VOICE="false"
    STATION_EXTRA=""
}

# Load a station file into the current shell.  It is sourced in a subshell,
# with the settings cleared first (a station file writes HARDWARE as
# ${HARDWARE:=...}, which an inherited value would override).  Settings that
# are not in STATION_VARS land in STATION_EXTRA, as "NAME=value" lines.
station_load()
{
    local file="$1" dump

    station_installer_defaults
    dump="$(
        for v in ${STATION_VARS}; do unset "${v}"; done
        set +o nounset
        # shellcheck disable=SC1090
        . "${file}" > /dev/null 2>&1
        for v in ${STATION_VARS}; do
            [ -n "${!v+x}" ] && printf '%s=%q\n' "${v}" "${!v}"
        done
        extra=""
        for v in $(grep -oE '^[A-Z_][A-Z0-9_]*=' "${file}" | tr -d '=' | sort -u); do
            case " ${STATION_VARS} FIRST_INSTALL " in
                *" ${v} "*) ;;
                *) extra="${extra}${v}=\"${!v}\""$'\n' ;;
            esac
        done
        printf 'STATION_EXTRA=%q\n' "${extra}"
    )"
    eval "${dump}"

    # as common.sh picks the controller
    if [ -z "${RADIO_CONTROLLER}" ]; then
        if [ "${HARDWARE}" = "hamlib" ]; then
            RADIO_CONTROLLER="radiod"
        else
            RADIO_CONTROLLER="sbitx_controller"
        fi
    fi
}

# The station file for the settings in the current shell.  Only what applies
# to the station's hardware and modem is written.
station_render()
{
    cat << EOF
## HERMES station ${HERMES_HOSTNAME}, written by hermes-setup

## Hostname, and the station's name in the stations/ directory
HERMES_HOSTNAME="${HERMES_HOSTNAME}"
## Callsign; the UUCP (or NNCP) node name
CALLSIGN="${CALLSIGN}"
## This station's name in its network's UUCP files
UUCP_ALIAS="${UUCP_ALIAS}"
## The network (conf/sys.<net>, conf/sys-gw.<net>, conf/transport.<net>)
UUCP_NET="${UUCP_NET}"
## "remote" or "gateway"
HERMES_ROLE="${HERMES_ROLE}"

## Interface language: en, es, pt or fr
HERMES_LANGUAGE="${HERMES_LANGUAGE}"
TIMEZONE="${TIMEZONE}"
## The domain of the TLS certificate in conf/ssl/
SSL_DOMAIN="${SSL_DOMAIN}"
## GUI emergency contact
EMERGENCY_EMAIL="${EMERGENCY_EMAIL}"
## Address that forwards to every user of the station
HERMES_FWD_EMAIL="${HERMES_FWD_EMAIL}"

## Radio: sbitx, hamlib (a CAT radio through Hamlib) or ubitx
HARDWARE=\${HARDWARE:="${HARDWARE}"}
EOF

    case "${HARDWARE}" in
        sbitx)
            cat << EOF
## Radio controller: radiod (hermes-radio-daemon) or sbitx_controller
RADIO_CONTROLLER="${RADIO_CONTROLLER}"
## sBitx display: v1 or v2
DISPLAY_TYPE="${DISPLAY_TYPE}"
EOF
            if [ -n "${DIGITAL_VOICE_CODEC}" ]; then
                cat << EOF
## What the web interface's Digital voice switch runs (radiod): radev2 or dstar
DIGITAL_VOICE_CODEC="${DIGITAL_VOICE_CODEC}"
EOF
            fi
            ;;
        hamlib)
            cat << EOF
RADIO_CONTROLLER="radiod"
## Hamlib model number (rigctl -l), serial port and rate, PTT and USB codec
RIG_MODEL="${RIG_MODEL}"
RIG_DEVICE="${RIG_DEVICE}"
RIG_SERIAL_RATE="${RIG_SERIAL_RATE}"
RIG_PTT_TYPE="${RIG_PTT_TYPE}"
RIG_AUDIO_DEVICE="${RIG_AUDIO_DEVICE}"
EOF
            ;;
        ubitx)
            cat << EOF
## PC sound card (conf/asound.state.<card>)
SOUND_CARD="${SOUND_CARD}"
## Flash the uBITX firmware (1) or not (0), and the Raduino version
INSTALL_FIRMWARE="${INSTALL_FIRMWARE}"
RADUINO_VER=\${RADUINO_VER:="${RADUINO_VER}"}
EOF
            ;;
    esac

    cat << EOF

## Modem: mercury or vara
MODEM_TYPE="${MODEM_TYPE}"
EOF
    if [ "${MODEM_TYPE}" = "vara" ]; then
        cat << EOF
VARA_KEY="${VARA_KEY}"
EOF
    fi

    cat << EOF
## Radio transport: UUCP (default), or NNCP when true
NNCP_ENABLED="${NNCP_ENABLED}"
## UUCP pre-agreed startup (uucico -Y, uucpd -F)
UUCP_PRE_AGREED="${UUCP_PRE_AGREED}"

HAS_GPS="${HAS_GPS}"
EOF
    if [ -n "${GPS_MAP}" ]; then
        echo "GPS_MAP=\"${GPS_MAP}\""
    fi
    cat << EOF
## GUI asks for a login
REQUIRE_LOGIN="${REQUIRE_LOGIN}"
## Random passwords, key-only SSH, own certificate (see common.sh)
HERMES_HARDENING="${HERMES_HARDENING}"
## Encrypted mailboxes (Debian 13)
MAIL_ENCRYPTION="${MAIL_ENCRYPTION}"
EOF

    if [ "${HARDWARE}" != "ubitx" ]; then
        cat << EOF

## Radio profiles: 0 is data, 1 is voice.  DEFAULT_VOICE starts in voice.
## A frequency (Hz) or mode left out keeps what the radio has.
DEFAULT_VOICE="${DEFAULT_VOICE}"
EOF
        local v
        for v in DEFAULT_DATA_FREQUENCY DEFAULT_DATA_MODE DEFAULT_VOICE_FREQUENCY DEFAULT_VOICE_MODE; do
            if [ -n "${!v}" ]; then
                echo "${v}=\"${!v}\""
            fi
        done
    fi

    if [ -n "${STATION_EXTRA}" ]; then
        printf '\n## Other settings, kept from the previous file\n%s' "${STATION_EXTRA}"
    fi
}

# What is wrong with the settings in the current shell, one line each;
# nothing when they are fine.
station_check()
{
    local installer_dir="$1"

    [[ "${HERMES_HOSTNAME}" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$ ]] \
        || echo "Hostname \"${HERMES_HOSTNAME}\" is not a full lowercase name such as station1.hermes.radio"
    [[ "${CALLSIGN}" =~ ^[A-Za-z0-9-]+$ ]] \
        || echo "Callsign \"${CALLSIGN}\" must be letters, digits and dashes"
    [[ "${UUCP_ALIAS}" =~ ^[A-Za-z0-9_-]+$ ]] \
        || echo "UUCP alias \"${UUCP_ALIAS}\" must be letters, digits, _ and -"
    # gateways are often "gw" in their own file; remote stations must not be
    if [ "${UUCP_ALIAS}" = "local" ] || { [ "${UUCP_ALIAS}" = "gw" ] && [ "${HERMES_ROLE}" != "gateway" ]; }; then
        echo "UUCP alias \"${UUCP_ALIAS}\" is reserved"
    fi
    [[ "${UUCP_NET}" =~ ^[A-Za-z0-9_-]+$ ]] \
        || echo "Network \"${UUCP_NET}\" must be letters, digits, _ and -"
    [ -f "/usr/share/zoneinfo/${TIMEZONE}" ] \
        || echo "Unknown timezone \"${TIMEZONE}\""
    if [ -n "${installer_dir}" ] && [ ! -s "${installer_dir}/conf/ssl/${SSL_DOMAIN}/${SSL_DOMAIN}.crt" ]; then
        echo "No certificate for \"${SSL_DOMAIN}\" in conf/ssl/ (the installer falls back to hermes.radio)"
    fi
    if [ "${HARDWARE}" = "hamlib" ]; then
        [[ "${RIG_MODEL}" =~ ^[0-9]+$ ]] || echo "Hamlib radios need RIG_MODEL, a number (rigctl -l)"
        [[ "${RIG_SERIAL_RATE}" =~ ^[0-9]+$ ]] || echo "Serial rate \"${RIG_SERIAL_RATE}\" is not a number"
    fi
    case "${DIGITAL_VOICE_CODEC}" in
        ""|radev2) ;;
        dstar)
            if [ "${HARDWARE}" != "sbitx" ] || [ "${RADIO_CONTROLLER}" != "radiod" ]; then
                echo "D-STAR digital voice needs an sBitx with radiod"
            fi
            ;;
        *) echo "Digital voice \"${DIGITAL_VOICE_CODEC}\" is radev2 or dstar" ;;
    esac
    if [ "${HARDWARE}" = "ubitx" ] && [ -n "${installer_dir}" ] \
       && [ ! -f "${installer_dir}/conf/asound.state.${SOUND_CARD}" ]; then
        echo "No conf/asound.state.${SOUND_CARD} for this sound card"
    fi
    if [ "${MODEM_TYPE}" = "vara" ] && [ -z "${VARA_KEY}" ]; then
        echo "VARA needs its license key"
    fi
    if [ "${HARDWARE}" != "ubitx" ]; then
        [[ "${DEFAULT_DATA_FREQUENCY}" =~ ^[0-9]*$ ]] || echo "Data frequency must be in Hz"
        [[ "${DEFAULT_VOICE_FREQUENCY}" =~ ^[0-9]*$ ]] || echo "Voice frequency must be in Hz"
    fi
}

# The networks that have files in conf/.
network_list()
{
    local installer_dir="$1"

    ls "${installer_dir}"/conf/sys.* "${installer_dir}"/conf/sys-gw.* 2> /dev/null \
        | sed -E 's|.*/sys(-gw)?\.||' | sort -u
}

# The gateway of a network: the system that sys-gw.<net> calls "local".
network_gateway()
{
    local installer_dir="$1" net="$2"

    awk '/^system/ { s = $2 } /^alias[ \t]+local[ \t]*$/ { print s; exit }' \
        "${installer_dir}/conf/sys-gw.${net}" 2> /dev/null
}

# The stations of a network, as "callsign alias" lines, gateway excluded.
network_stations()
{
    local installer_dir="$1" net="$2"

    awk '/^system/ { s = $2 }
         /^alias/ && s != "" && $2 != "local" && $2 != "gw" { print s, $2; s = "" }' \
        "${installer_dir}/conf/sys.${net}" 2> /dev/null
}

# New network: its three files, with the gateway and no stations.
#   network_create <installer_dir> <net> <gateway callsign> <central address>
network_create()
{
    local installer_dir="$1" net="$2" gw_call="$3" central="$4"
    local conf="${installer_dir}/conf"
    local login password

    # the network's UUCP login, as in conf/passwd ("login password"), which
    # the installer also gives every station
    read -r login password < <(grep -vE '^[[:space:]]*(#|$)' "${conf}/passwd" 2> /dev/null | head -1)
    if [ -z "${login}" ] || [ -z "${password}" ]; then
        echo "conf/passwd has no \"login password\" line" >&2
        return 1
    fi

    if [ -e "${conf}/sys.${net}" ] || [ -e "${conf}/sys-gw.${net}" ] || [ -e "${conf}/transport.${net}" ]; then
        echo "Network ${net} already exists" >&2
        return 1
    fi

    cat > "${conf}/sys-gw.${net}" << EOF
time any

chat-timeout 600
call-login ${login}
call-password ${password}
chat "" \\r

port HFP

forward *
commands rmail rnews crmail bash uucp uuadm ubitx_client sudo dec_sensors dec_message

protocol yi
protocol-parameter y packet-size 512
protocol-parameter y timeout 5400

system hermes
alias gw
port TCP
protocol i
address ${central}
chat "" \\d\\d\\r\\c ogin: \\d\\L word: \\P

system ${gw_call}
alias local
EOF

    cat > "${conf}/sys.${net}" << EOF
time any

chat-timeout 900
call-login ${login}
call-password ${password}
chat "" \\r

port HFP

forward ANY
commands rmail crmail bash uucp uuadm ubitx_client sudo dec_sensors dec_message

protocol y
protocol-parameter y packet-size 512
protocol-parameter y timeout 5400

system ${gw_call}
alias gw
EOF

    : > "${conf}/transport.${net}"
}

# Add a remote station to its network's files; nothing changes for one that
# is there already.
#   network_add_station <installer_dir> <net> <callsign> <alias> <hostname>
network_add_station()
{
    local installer_dir="$1" net="$2" call="$3" alias="$4" host="$5"
    local conf="${installer_dir}/conf" f

    for f in "${conf}/sys.${net}" "${conf}/sys-gw.${net}"; do
        [ -f "${f}" ] || { echo "Network ${net} has no ${f##*/}" >&2; return 1; }
        if ! grep -qE "^system[ \t]+${call}[ \t]*$" "${f}"; then
            # one blank line between systems, as in the files by hand
            [ -z "$(tail -c 1 "${f}")" ] || echo >> "${f}"
            [ -z "$(tail -n 1 "${f}")" ] || echo >> "${f}"
            printf 'system %s\nalias %s\n' "${call}" "${alias}" >> "${f}"
        fi
    done

    touch "${conf}/transport.${net}"
    if ! grep -qE "^${host//./\\.}[ \t]" "${conf}/transport.${net}"; then
        [ -z "$(tail -c 1 "${conf}/transport.${net}")" ] || echo >> "${conf}/transport.${net}"
        printf '%s       uucp:%s\n' "${host}" "${alias}" >> "${conf}/transport.${net}"
    fi
}
