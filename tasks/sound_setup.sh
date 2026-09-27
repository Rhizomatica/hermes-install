# to be read...

do_sound_setup()
{

    # The radio controller bridges the radio's codec (the sBitx's own, or a
    # Hamlib rig's USB one) to snd-aloop cards, which the modem uses.
    if [ "${HARDWARE}" = "sbitx" ] || [ "${HARDWARE}" = "hamlib" ]; then
        echo -e "${Red}SETTING UP ALSA FOR ${HARDWARE}-BASED HERMES${Color_Off}"
# done from hermes-net
#        install -C -g root -o root -m 644 conf/asound-sbitx.conf /etc/asound.conf
        echo snd-aloop > /etc/modules
        echo i2c-dev >> /etc/modules
        echo options snd-aloop enable=1,1,1 index=1,2,3 timer_source=hw:0,0 > /etc/modprobe.d/aloop.conf
        #        echo options snd-aloop enable=1,1,1 index=1,2,3 > /etc/modprobe.d/aloop.conf
    else
        echo -e "${Red}SETTING UP ALSA FOR UBITX-BASED HERMES${Color_Off}"
        install -C -g root -o root -m 644 conf/intel_hda.conf /etc/modprobe.d/intel_hda.conf
        install -C -g root -o root -m 644 conf/asound.state.${SOUND_CARD} /var/lib/alsa/asound.state
        set +e
        alsactl restore
        set -e
    fi

}
