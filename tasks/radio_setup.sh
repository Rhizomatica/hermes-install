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

    systemctl daemon-reload
}

do_radiod_setup()
{
    echo -e "${Red}INSTALLING HERMES-RADIO-DAEMON${Color_Off}"

    # radiod's build dependencies, by their Debian/HERMES names: libfftw3-dev
    # carries the single precision fftw3f too, and csdr is the HERMES
    # repository's libcsdr, headers included.
    apt-get -y install libhamlib-dev libiniparser-dev libasound2-dev libfftw3-dev \
            libssl-dev libi2c-dev csdr libspecbleach-dev \
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

    configure_radio_profiles /etc/hermes/user.ini " = "
}
