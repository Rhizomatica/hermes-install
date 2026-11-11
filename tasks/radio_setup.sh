# to be called by hermes installer
#
# The radio controller: the program that drives the radio and that the
# modem, uucpd and the GUI reach through its shared memory and websocket.
#   RADIO_CONTROLLER=sbitx_controller  the old sBitx controller from hermes-net
#   RADIO_CONTROLLER=radiod            hermes-radio-daemon: an sBitx
#                                      (HARDWARE=sbitx) or a CAT radio such as
#                                      the IC-7100 through Hamlib
#                                      (HARDWARE=hamlib)
# Both drive the same hardware, so exactly one of them is enabled.

# Set "key = value" in the [main] section of an ini file, adding the key if
# it is not there.
ini_set_main()
{
    local file="$1" key="$2" value="$3"

    if grep -qE "^${key}[[:space:]]*=" "${file}"; then
        sed -i "s|^${key}[[:space:]]*=.*|${key} = ${value}|" "${file}"
    else
        sed -i "0,/^\[main\]/s||[main]\n${key} = ${value}|" "${file}"
    fi
}

# Set a key in one [section] of a user.ini.  sbitx_controller writes
# "key=value" and radiod "key = value", so keep the file's own style.
ini_set_section()
{
    local file="$1" section="$2" key="$3" value="$4" sep="$5"

    sed -i "/^\[${section}\]/,/^\[/{s|^${key}[[:space:]]*=.*|${key}${sep}${value}|}" "${file}"
}

# Set "key = value" in one [section] of an ini file, adding the key after
# the section's last setting, or the section at the end of the file, when
# missing.
ini_set()
{
    local file="$1" section="$2" key="$3" value="$4"

    touch "${file}"
    awk -v section="[${section}]" -v key="${key}" -v line="${key} = ${value}" '
        function header(s) { gsub(/[[:space:]]/, "", s); return s }
        # blank and comment lines at the end of a section belong to the next
        function flush() { printf "%s", held; held = "" }
        /^[[:space:]]*\[/ {
            if (in_sec && !done) { print line; done = 1 }
            flush()
            in_sec = (header($0) == section)
            print; next
        }
        /^[[:space:]]*([;#]|$)/ { held = held $0 "\n"; next }
        in_sec && !done && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
            flush(); print line; done = 1; next
        }
        { flush(); print }
        END {
            if (!done) {
                if (!in_sec) { flush(); print section }
                print line
            }
            flush()
        }' "${file}" > "${file}.new"
    cat "${file}.new" > "${file}"
    rm -f "${file}.new"
}

# The value of a key in one [section] of an ini file, without quotes.
ini_get()
{
    local file="$1" section="$2" key="$3"

    [ -f "${file}" ] || return 0
    awk -v section="[${section}]" -v key="${key}" '
        function header(s) { gsub(/[[:space:]]/, "", s); return s }
        /^[[:space:]]*\[/ { in_sec = (header($0) == section); next }
        in_sec && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
            sub(/^[^=]*=[[:space:]]*/, ""); gsub(/"/, ""); sub(/[[:space:]]+$/, "")
            print; exit
        }' "${file}"
}

# Mercury's user interface, on for every station that installs Mercury, in
# mercury.ini (main:ui_enabled).
configure_mercury_ui()
{
    local ini=/etc/mercury/mercury.ini

    mkdir -p /etc/mercury
    ini_set ${ini} main ui_enabled true
}

# How Mercury hears and keys the radio (MODEM_AUDIO), in mercury.ini:
#   rtp       radiod's RTP streams on lo (main:enable_rtp_audio); radiod keys
#             the radio from the stream, so Mercury has no PTT of its own
#   loopback  the snd-aloop cables (ALSA "default", see asound.conf), keying
#             the radio through radiod's shared memory
# Unset leaves mercury.ini as it is.
configure_mercury_audio()
{
    local ini=/etc/mercury/mercury.ini

    mkdir -p /etc/mercury
    case "${MODEM_AUDIO}" in
        rtp)
            ini_set ${ini} main sound_system rtp
            ini_set ${ini} main input_device "\"239.255.72.1,lo\""
            ini_set ${ini} main output_device "\"239.255.72.2\""
            ini_set ${ini} ptt method none
            ;;
        loopback)
            ini_set ${ini} main sound_system alsa
            ini_set ${ini} main input_device "\"default\""
            ini_set ${ini} main output_device "\"default\""
            ini_set ${ini} ptt method hermes_shm
            ;;
    esac
}

# Digital voice in the voice profile (DIGITAL_VOICE) and its encryption
# (VOICE_ENCRYPTION); unset leaves the radio as it is.  Under DSTAR radiod
# puts a profile saved with digital_voice = 1 in D-STAR mode at its next
# start, and keeps the mode to go back to in dv_restore_mode.
configure_digital_voice()
{
    local core=/etc/hermes/core.ini user=/etc/hermes/user.ini restore

    case "${DIGITAL_VOICE}" in
        true)
            ini_set ${user} profile1 digital_voice 1
            ;;
        false)
            ini_set ${user} profile1 digital_voice 0
            restore="$(ini_get ${user} profile1 dv_restore_mode)"
            if [ "$(ini_get ${user} profile1 mode)" = "DSTAR" ] && [ -n "${restore}" ]; then
                ini_set ${user} profile1 mode "${restore}"
                ini_set ${user} profile1 dv_restore_mode ""
            fi
            ;;
    esac

    # Every station of the network holds the same key, from the installer's
    # conf/voice-key/<network>.key.  Encryption is not allowed on amateur
    # bands.
    case "${VOICE_ENCRYPTION}" in
        true)
            local key="${INSTALLER_DIRECTORY}/conf/voice-key/${UUCP_NET}.key"
            if ! grep -qxE '[0-9a-fA-F]{64}' "${key}" 2> /dev/null; then
                echo -e "${Red}VOICE_ENCRYPTION needs ${key}, 64 hex digits. Aborting.${Color_Off}"
                exit 1
            fi
            install -m 600 -o root -g root "${key}" /etc/hermes/voice.key
            ini_set_main ${core} voice_key_file /etc/hermes/voice.key
            ini_set_main ${core} rade_encrypt 1
            ini_set_main ${core} dstar_encrypt 1
            ;;
        false)
            ini_set_main ${core} rade_encrypt 0
            ini_set_main ${core} dstar_encrypt 0
            ;;
    esac
}

# Apply the station's profile settings (DEFAULT_VOICE, DEFAULT_*_FREQUENCY,
# DEFAULT_*_MODE) to the controller's user.ini.  The controller rewrites
# that file while it runs, so it must be stopped first.
configure_radio_profiles()
{
    local file="$1" sep="$2"

    if [[ "$DEFAULT_VOICE" == "true" ]]; then
        echo -e "${Red}Configuring the radio for DEFAULT_VOICE mode${Color_Off}"
        sed -i "s|^current_profile[[:space:]]*=.*|current_profile${sep}1|" "${file}"
        sed -i "s|^default_profile[[:space:]]*=.*|default_profile${sep}1|" "${file}"
        sed -i "s|^default_profile_fallback_timeout[[:space:]]*=.*|default_profile_fallback_timeout${sep}-1|" "${file}"
        ini_set_section "${file}" profile1 enable_knob_frequency 0 "${sep}"
    fi

    if [[ -n "${DEFAULT_DATA_FREQUENCY:-}" ]]; then
        echo -e "${Red}Setting DEFAULT_DATA_FREQUENCY=${DEFAULT_DATA_FREQUENCY}${Color_Off}"
        ini_set_section "${file}" profile0 freq "${DEFAULT_DATA_FREQUENCY}" "${sep}"
    fi
    if [[ -n "${DEFAULT_DATA_MODE:-}" ]]; then
        echo -e "${Red}Setting DEFAULT_DATA_MODE=${DEFAULT_DATA_MODE}${Color_Off}"
        ini_set_section "${file}" profile0 mode "${DEFAULT_DATA_MODE}" "${sep}"
    fi
    if [[ -n "${DEFAULT_VOICE_FREQUENCY:-}" ]]; then
        echo -e "${Red}Setting DEFAULT_VOICE_FREQUENCY=${DEFAULT_VOICE_FREQUENCY}${Color_Off}"
        ini_set_section "${file}" profile1 freq "${DEFAULT_VOICE_FREQUENCY}" "${sep}"
    fi
    if [[ -n "${DEFAULT_VOICE_MODE:-}" ]]; then
        echo -e "${Red}Setting DEFAULT_VOICE_MODE=${DEFAULT_VOICE_MODE}${Color_Off}"
        ini_set_section "${file}" profile1 mode "${DEFAULT_VOICE_MODE}" "${sep}"
    fi
}

# hermes-net used to install its units in /etc/systemd/system, where they
# shadow the ones it now ships in /usr/lib/systemd/system.  Move them aside,
# keeping what a station had changed in them: uucpd's options go to
# /etc/default/uucpd, any other unit's command line to a drop-in.
migrate_hermesnet_units()
{
    local unit old line opts

    # A hermes-net that still installs into /etc/systemd/system (such as
    # maintenance-debian12) has nothing to migrate to.
    [ -f "${TMP_PATH}/hermes-net/system_services/default/uucpd" ] || return 0

    for unit in uucpd sbitx modem caller ubitx; do
        old="/etc/systemd/system/${unit}.service"
        [ -f "${old}" ] && [ ! -L "${old}" ] || continue

        echo -e "${Red}Moving the old ${old} aside${Color_Off}"
        line="$(grep -m1 '^ExecStart=' "${old}" || true)"

        if [ "${unit}" = "uucpd" ]; then
            # Keep options that key the radio through its controller.  Ones
            # that key it directly (-o icom, -o ubitx, with -s) date from
            # VARA without a controller, and would fight a controller for
            # the radio's CAT port; leave those for the operator.
            opts="${line#ExecStart=/usr/bin/uucpd }"
            if [ -n "${line}" ] && [ "${opts}" != "${line}" ] \
               && [ "${opts}" != "-a 127.0.0.1 -p 8300 -r vara -o shm -f 2750p -m" ] \
               && ! grep -qE '^UUCPD_OPTS=' /etc/default/uucpd 2>/dev/null; then
                if echo " ${opts} " | grep -qE ' -o (shm|none) '; then
                    echo "UUCPD_OPTS=\"${opts}\"" >> /etc/default/uucpd
                else
                    echo -e "${Red}Not keeping the old uucpd options \"${opts}\"; see ${old}.pre-dropin${Color_Off}"
                fi
            fi
            if [ "${MODEM_TYPE}" = "vara" ] && grep -qE '^Requires=.*vnc\.service' "${old}"; then
                mkdir -p /etc/systemd/system/uucpd.service.d
                printf '[Unit]\nRequires=vnc.service\nAfter=vnc.service\n' \
                       > /etc/systemd/system/uucpd.service.d/vnc.conf
            fi
        elif [ -n "${line}" ] && ! grep -qxF "${line}" "${TMP_PATH}/hermes-net/system_services/init/${unit}.service"; then
            mkdir -p "/etc/systemd/system/${unit}.service.d"
            printf '# Kept from the %s hermes-net used to install here.\n[Service]\nExecStart=\n%s\n' \
                   "${old}" "${line}" > "/etc/systemd/system/${unit}.service.d/00-pre-dropin.conf"
        fi

        mv "${old}" "${old}.pre-dropin"
    done

    # Not in an image build (installer.sh -v under systemd-nspawn): there is
    # no running systemd there, and daemon-reload fails, stopping the install.
    if [ -d /run/systemd/system ]; then
        systemctl daemon-reload
    fi
}

# radiod has no built-in per-band TX power scales: with no [tx_band*] section
# covering the frequency the multiplier is 0 ("Error finding band gain!")
# and nothing is transmitted.  A core.ini kept from an older install, or
# made from a template that had them commented out, lacks them.  Take the
# station's own calibration from the old /etc/sbitx/core.ini if there is
# one, else the defaults of the template that came with this radiod ($1).
ensure_tx_band_calibration()
{
    local core=/etc/hermes/core.ini template="$1" src

    if grep -qE '^\[tx_band0\]' "${core}"; then
        return 0
    fi

    for src in /etc/sbitx/core.ini "${template}"; do
        if grep -qE '^\[tx_band0\]' "${src}" 2> /dev/null; then
            echo -e "${Red}Adding the TX power calibration of ${src} to ${core}${Color_Off}"
            printf '\n' >> "${core}"
            # Only the [tx_band*] sections, not what may follow them.
            awk '/^\[/ { keep = ($0 ~ /^\[tx_band[0-9]+\]/) } keep' "${src}" >> "${core}"
            return 0
        fi
    done

    echo -e "${Red}WARNING: no [tx_band*] TX power calibration in ${core}: radiod will not transmit${Color_Off}"
}

do_radiod_setup()
{
    echo -e "${Red}INSTALLING HERMES-RADIO-DAEMON${Color_Off}"

    # The package lists first: a run of only this task has no system task
    # before it to refresh them, and the packages below may be newer than
    # the station's lists.  Without them the old libspecbleach would be
    # removed and the new one not found, and radiod could not start again.
    apt-get update

    # A station may still have libspecbleach 0.3.0 installed by hand, as
    # libspecbleach1: it holds the same libspecbleach.so.0 as the HERMES
    # repository's libspecbleach0, which has another ABI.
    if dpkg -s libspecbleach1 > /dev/null 2>&1; then
        apt-get -y remove libspecbleach-dev libspecbleach1
    fi

    # radiod's build dependencies, by their Debian/HERMES names: libfftw3-dev
    # carries the single precision fftw3f too, and csdr (libcsdr, headers
    # included), libspecbleach-dev and libmbe-neo-dev (mbelib-neo, D-STAR's
    # AMBE) come from the HERMES repository.
    apt-get -y install libhamlib-dev libiniparser-dev libasound2-dev libfftw3-dev \
            libssl-dev libi2c-dev csdr libspecbleach-dev libmbe-neo-dev \
            libsndfile1-dev libcw-dev meson ninja-build pkg-config

    mkdir -p ${TMP_PATH}
    cd ${TMP_PATH}
    rm -rf hermes-radio-daemon
    git clone https://github.com/Rhizomatica/hermes-radio-daemon
    cd hermes-radio-daemon/
    if [ -n "${HERMES_RADIO_DAEMON_BRANCH}" ]; then
        git checkout "${HERMES_RADIO_DAEMON_BRANCH}"
    fi
    make
    make install
    ensure_tx_band_calibration "${PWD}/config/core.ini"
    cd ${TMP_PATH} && rm -rf hermes-radio-daemon

    # radio_client speaks sbitx_client's command line; the API and the
    # scripts call it by that name.
    ln -sf radio_client /usr/bin/sbitx_client

    set +e
    systemctl stop radiod
    set -e

    local core=/etc/hermes/core.ini
    ini_set_main ${core} enable_shm_control 1
    ini_set_main ${core} enable_websocket 1
    ini_set_main ${core} websocket_url wss://0.0.0.0:8080

    if [ "${HARDWARE}" = "sbitx" ]; then
        ini_set_main ${core} radio_backend hfsignals
        ini_set_main ${core} hw_profile sbitx
        ini_set_main ${core} i2c_dev /dev/i2c-sbitx
        # D-STAR sends the station's callsign in every over: the callsign
        # without its -N, at most 8 characters.
        local mycall="${CALLSIGN%%-*}"
        mycall="${mycall^^}"
        ini_set_main ${core} dstar_mycall "${mycall:0:8}"
        # What the web interface's Digital voice switch runs; a station file
        # without it leaves core.ini as it is (radiod's default is RADEV2).
        if [ -n "${DIGITAL_VOICE_CODEC}" ]; then
            ini_set_main ${core} digital_voice_codec "${DIGITAL_VOICE_CODEC^^}"
        fi
    else
        # The daemon bridges the rig's USB codec to the snd-aloop cards the
        # modem uses, as the sBitx does with its own codec.
        ini_set_main ${core} radio_backend hamlib
        ini_set_main ${core} radio_model "${RIG_MODEL}"
        ini_set_main ${core} rig_pathname "${RIG_DEVICE}"
        ini_set_main ${core} serial_rate "${RIG_SERIAL_RATE}"
        ini_set_main ${core} ptt_type "${RIG_PTT_TYPE}"
        ini_set_main ${core} enable_loop_audio 1
        ini_set_main ${core} loop_playback_device hw:1,0
        ini_set_main ${core} loop_capture_device hw:2,1
        ini_set_main ${core} capture_device "${RIG_AUDIO_DEVICE}"
        ini_set_main ${core} playback_device "${RIG_AUDIO_DEVICE}"
    fi

    # The modem's audio: radiod always opens the snd-aloop cables (the
    # modem's start waits for them); with rtp it streams to Mercury too.
    case "${MODEM_AUDIO}" in
        rtp)      ini_set_main ${core} enable_rtp_audio 1 ;;
        loopback) ini_set_main ${core} enable_rtp_audio 0 ;;
    esac
    if [ "${MODEM_TYPE}" = "mercury" ]; then
        configure_mercury_audio
    fi

    configure_digital_voice
    configure_radio_profiles /etc/hermes/user.ini " = "
}
