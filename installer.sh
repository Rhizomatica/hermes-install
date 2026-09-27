#!/bin/bash
#
### This is the HERMES station installer

set -o nounset
set -o errexit

. library.sh

. tasks/secrets_setup.sh
. tasks/system_setup.sh
. tasks/do_1st_boot_setup.sh
. tasks/db_create.sh
. tasks/vpn_setup.sh
. tasks/vpn_wireguard.sh
. tasks/sound_setup.sh
. tasks/wifi_module.sh
. tasks/network_setup.sh
. tasks/uucp_setup.sh
. tasks/nncp_setup.sh
. tasks/broadcast_setup.sh
. tasks/hermes-net_setup.sh
. tasks/radio_setup.sh
. tasks/certificate_setup.sh
. tasks/web-server_setup.sh
. tasks/deltachat_download.sh
. tasks/email_setup.sh
. tasks/roundcube_setup.sh
. tasks/api_setup.sh
. tasks/gui_setup.sh
. tasks/erase_config.sh
. tasks/gps_setup.sh

# The installation, task by task, in the order it runs.  "--list-tasks"
# prints them; "--tasks a,b,..." runs only those, still in this order.  The
# station secrets are always set up first: every task reads the passwords
# they keep.
TASKS="system vpn sound wifi certificate gps network transport hermesnet broadcast webserver deltachat api gui email roundcube db firstboot"

task_description()
{
    case "$1" in
        system)      echo "Base system: packages, boot, users, kiosk" ;;
        vpn)         echo "OpenVPN client" ;;
        sound)       echo "ALSA and the loopback cards" ;;
        wifi)        echo "WiFi driver (not on an sBitx)" ;;
        certificate) echo "TLS certificate" ;;
        gps)         echo "paq8px, hermes-sensors and GPS" ;;
        network)     echo "Network interfaces, dnsmasq, WiFi access point" ;;
        transport)   echo "UUCP, or NNCP when NNCP_ENABLED" ;;
        hermesnet)   echo "hermes-net, the modem and the radio controller" ;;
        broadcast)   echo "Encrypted broadcast (NNCP with Mercury only)" ;;
        webserver)   echo "nginx and PHP" ;;
        deltachat)   echo "Delta Chat downloads for the users" ;;
        api)         echo "HERMES API" ;;
        gui)         echo "HERMES web interface (built on the station)" ;;
        email)       echo "Postfix, Dovecot and the mail transport" ;;
        roundcube)   echo "Roundcube webmail (first install only)" ;;
        db)          echo "Databases (kept on a reinstall)" ;;
        firstboot)   echo "First boot: EEPROM, services, done marker" ;;
        *)           return 1 ;;
    esac
}

run_task()
{
    cd "${INSTALLER_DIRECTORY}"

    case "$1" in
        system)      do_system_setup ;;
        vpn)         do_vpn_setup ;;
        sound)       do_sound_setup ;;
        wifi)        do_wifi_module_setup ;;
        certificate) do_certificate_setup ;;
        gps)         do_gps_setup ;;
        network)     do_network_setup ;;
        transport)
            if [ "${NNCP_ENABLED:-false}" = "true" ]; then
                do_nncp_setup
            else
                do_uucp_setup
            fi
            ;;
        hermesnet)   do_hermesnet_setup ;;
        broadcast)
            # the broadcast plane is Mercury's, and hermes-net installs Mercury
            if [ "${NNCP_ENABLED:-false}" = "true" ] && [ "${MODEM_TYPE}" = "mercury" ]; then
                do_broadcast_setup
            fi
            ;;
        webserver)   do_webserver_setup ;;
        deltachat)   do_deltachat_download ;;
        api)         do_api_setup ;;
        gui)         do_gui_install ;;
        email)       do_email_setup ;;
        roundcube)   do_roundcube_setup ;;
        db)          db_create ;;
        firstboot)   do_1st_boot_setup ;;
    esac
}

usage()
{
    echo "Usage: installer.sh [station_name] [-v] [--tasks task,task,...] [--list-tasks]"
    echo "station_name: Name of the station to install (default: node hostname)"
    echo "-v: Install in a systemd-nspawn virtual environment"
    echo "--tasks: run only these tasks, in the installer's order (default: all)"
    echo "--list-tasks: print the tasks and what they do"
    echo "hermes-setup is the menu-driven way to pick tasks and write station files."
}

virtual_env=false
station_name=""
selected_tasks="${TASKS}"
while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
        -h|--help)
            usage
            exit 0
            ;;
        -v)
            virtual_env=true
            shift
            ;;
        --list-tasks)
            for task in ${TASKS}; do
                printf '%s\t%s\n' "${task}" "$(task_description "${task}")"
            done
            exit 0
            ;;
        --tasks)
            if [ $# -lt 2 ]; then
                usage
                exit 1
            fi
            selected_tasks="${2//,/ }"
            for task in ${selected_tasks}; do
                if ! task_description "${task}" > /dev/null; then
                    echo "Unknown task: ${task} (see --list-tasks)"
                    exit 1
                fi
            done
            shift 2
            ;;
        -*)
            usage
            exit 1
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

# a reinstall keeps the databases; HERMES_ERASE_DB="true" starts them over
# (see tasks/db_create.sh)

do_secrets_setup

for task in ${TASKS}; do
    case " ${selected_tasks} " in
        *" ${task} "*)
            echo -e "${Red}=== TASK: ${task} ===${Color_Off}"
            run_task "${task}"
            ;;
    esac
done
