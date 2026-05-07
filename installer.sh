#!/bin/bash
#
### This is the HERMES station installer

set -o nounset
set -o errexit

. library.sh

. tasks/system_setup.sh
. tasks/do_1st_boot_setup.sh
. tasks/db_create.sh
. tasks/vpn_setup.sh
. tasks/vpn_wireguard.sh
. tasks/sound_setup.sh
. tasks/wifi_module.sh
. tasks/network_setup.sh
. tasks/uucp_setup.sh
. tasks/hermes-net_setup.sh
. tasks/certificate_setup.sh
. tasks/web-server_setup.sh
. tasks/deltachat_download.sh
. tasks/email_setup.sh
. tasks/roundcube_setup.sh
. tasks/api_setup.sh
. tasks/gui_setup.sh
. tasks/erase_config.sh
. tasks/gps_setup.sh

virtual_env=false
station_name=""
while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
        -h|--help)
            echo "Usage: installer.sh [station_name] [-v]"
            echo "station_name: Name of the station to install (default: node hostname)"
            echo "-v: Install in a systemd-nswpan virtual environment"
            exit 0
            ;;
        -v)
            virtual_env=true
            shift
            ;;
        *)
            station_name="$1"
            shift
            ;;
    esac
done


if [ -z "$station_name" ]; then
    # use the hostname as station name
    station_name=${station_name:=$(hostname)}
fi

station_file="stations/${station_name}"
if [ -f ${station_file} ]; then
  . ${station_file}
else
  echo "Error. Station ${station_name} not found in \"stations/\" directory!"
  exit 1
fi

#load debian version
. /etc/os-release

# load common VARIABLES to all stations and some cleanup work
. common.sh

echo -e "${Red}INSTALLING HERMES SYSTEM FOR ${HERMES_HOSTNAME}${Color_Off}"

# just use this to erase the db
## erase_db_setup

do_system_setup

do_vpn_setup

do_sound_setup

do_wifi_module_setup

do_certificate_setup

do_gps_setup

do_network_setup

do_uucp_setup

do_hermesnet_setup

do_webserver_setup

do_deltachat_download

do_api_setup

do_gui_install

do_email_setup

do_roundcube_setup

db_create

do_1st_boot_setup
