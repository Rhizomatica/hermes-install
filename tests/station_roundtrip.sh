#!/bin/bash
#
# hermes-setup rewrites station files.  For every file in stations/, load it
# and write it back as hermes-setup would, then check that the installer
# would see the same settings in both: the same values once common.sh has
# filled in its defaults, for every setting that applies to the station's
# hardware and modem.  FIRST_INSTALL is the one setting dropped on purpose
# (the installer finds out itself).
#
#   tests/station_roundtrip.sh [station_file...]

set -o nounset
set -o errexit

cd "$(dirname "$0")/.."
. setup/lib.sh

# The settings as the installer ends up with them, "NAME=value" per line.
effective()
{
    (
        for v in ${STATION_VARS}; do unset "${v}"; done
        set +o nounset
        . "$1" > /dev/null 2>&1
        # as common.sh and the tasks default them; an empty value and a
        # missing one mean the same to every task
        MODEM_TYPE="${MODEM_TYPE:-vara}"
        DISPLAY_TYPE="${DISPLAY_TYPE:-v1}"
        DEFAULT_VOICE="${DEFAULT_VOICE:-false}"
        if [ "${HARDWARE}" = "hamlib" ]; then
            RADIO_CONTROLLER="${RADIO_CONTROLLER:-radiod}"
        else
            RADIO_CONTROLLER="${RADIO_CONTROLLER:-sbitx_controller}"
        fi
        RIG_DEVICE="${RIG_DEVICE:-/dev/ttyUSB0}"
        RIG_SERIAL_RATE="${RIG_SERIAL_RATE:-19200}"
        RIG_PTT_TYPE="${RIG_PTT_TYPE:-RIG}"
        RIG_AUDIO_DEVICE="${RIG_AUDIO_DEVICE:-hw:CODEC,0}"
        NNCP_ENABLED="${NNCP_ENABLED:-false}"
        UUCP_PRE_AGREED="${UUCP_PRE_AGREED:-false}"
        HAS_GPS="${HAS_GPS:-false}"
        HERMES_HARDENING="${HERMES_HARDENING:-false}"
        MAIL_ENCRYPTION="${MAIL_ENCRYPTION:-true}"

        skip=" FIRST_INSTALL "
        case "${HARDWARE}" in
            sbitx)  skip="${skip} RIG_MODEL RIG_DEVICE RIG_SERIAL_RATE RIG_PTT_TYPE RIG_AUDIO_DEVICE SOUND_CARD INSTALL_FIRMWARE RADUINO_VER " ;;
            hamlib) skip="${skip} DISPLAY_TYPE SOUND_CARD INSTALL_FIRMWARE RADUINO_VER " ;;
            ubitx)  skip="${skip} RADIO_CONTROLLER DISPLAY_TYPE RIG_MODEL RIG_DEVICE RIG_SERIAL_RATE RIG_PTT_TYPE RIG_AUDIO_DEVICE DEFAULT_VOICE DEFAULT_DATA_FREQUENCY DEFAULT_DATA_MODE DEFAULT_VOICE_FREQUENCY DEFAULT_VOICE_MODE " ;;
        esac
        [ "${MODEM_TYPE}" = "vara" ] || skip="${skip} VARA_KEY "

        for v in ${STATION_VARS} $(grep -oE '^[A-Z_][A-Z0-9_]*=' "$1" | tr -d '=' | sort -u); do
            case "${skip}" in *" ${v} "*) continue ;; esac
            echo "${v}=${!v-}"
        done | sort -u
    )
}

tmp="$(mktemp)"
trap 'rm -f "${tmp}"' EXIT

files=("$@")
[ ${#files[@]} -gt 0 ] || files=(stations/*)

failed=0
for f in "${files[@]}"; do
    if [ ! -f "${f}" ]; then
        echo "FAIL ${f}: no such file"
        failed=$((failed + 1))
        continue
    fi
    station_load "${f}"
    station_render > "${tmp}"
    if ! bash -n "${tmp}"; then
        echo "FAIL ${f}: the rewritten file is not valid shell"
        failed=$((failed + 1))
        continue
    fi
    if ! out="$(diff <(effective "${f}") <(effective "${tmp}"))"; then
        echo "FAIL ${f}:"
        echo "${out}" | sed 's/^/    /'
        failed=$((failed + 1))
    fi
done

echo "${#files[@]} station files, ${failed} changed meaning"
[ "${failed}" -eq 0 ]
