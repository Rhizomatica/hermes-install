# to be read...

do_sound_setup()
{

    if [ ${HARDWARE} = "sbitx" ]; then
        echo -e "${Red}SETTING UP ALSA FOR SBITX-BASED HERMES${Color_Off}"
# done at hermes-net task
#        install -C -g root -o root -m 644 conf/asound-sbitx.conf /etc/asound.conf
        echo snd-aloop > /etc/modules
        echo i2c-dev >> /etc/modules
        echo options snd-aloop enable=1,1,1 index=1,2,3 timer_source=hw:0,0 > /etc/modprobe.d/aloop.conf
        #        echo options snd-aloop enable=1,1,1 index=1,2,3 > /etc/modprobe.d/aloop.conf
    else
        echo -e "${Red}NOT SETTING UP ALSA. DO IT MANUALLY, IF NEEDED.${Color_Off}"
#        install -C -g root -o root -m 644 conf/intel_hda.conf /etc/modprobe.d/intel_hda.conf
#        install -C -g root -o root -m 644 conf/asound.state.${SOUND_CARD} /var/lib/alsa/asound.state
#        set +e
#        alsactl restore
#        set -e
    fi

}
