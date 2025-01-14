# to be read by hermes-installer

do_wifi_module_setup()
{
    if [ "${HARDWARE}" != "sbitx" ]; then

       echo -e "${Red}INSTALLING WIFI DRIVER${Color_Off}"

       apt-get update
       apt-get -y install rtl8821cu-dkms

    fi
}
