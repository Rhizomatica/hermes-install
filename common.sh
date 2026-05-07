INSTALLER_DIRECTORY="$(pwd)"

TMP_PATH=/root/install

WEBPUB_PATH="/var/www"
WEBAPI_PATH="/var/www/station-api"
INBOX_PATH="/var/www/station-api/storage/app/inbox"
WEBGUI_PATH="/var/www/html"
DELTACHAT_DOWNLOAD_PATH="/var/www/html/downloads"
ROUNDCUBE_PATH="/var/www/html/email"


HERMES_DB="hermes"
HERMES_DB_USER="hermes"
HERMES_DB_PASSWORD="db_hermes"

# Default to false if DEFAULT_VOICE is unset
DEFAULT_VOICE="${DEFAULT_VOICE:-false}"

# use VARA as default modem if MODEM_TYPE not set
MODEM_TYPE="${MODEM_TYPE:-vara}"

# Default to v1 if DISPLAY_TYPE is unset
DISPLAY_TYPE="${DISPLAY_TYPE:-v1}"

#if [[ $station_name =~ "hermes" ]]; then
#  vpn_file_base=${station_name//./_}
#else
  vpn_file_base=${station_name}
#fi

# run me as root!
if [[ $(id -u) -ne 0 ]];
then
    echo "Please run as root";
    exit 1;
fi

if ! [ -x "$(command -v wget)" ]; then
    echo "Error: wget is not installed. Installing."
    apt-get -y install wget
fi

mkdir -p ${TMP_PATH}

# determine FIRST_INSTALL if it's not set by the user
FIRST_INSTALL="${FIRST_INSTALL:-}"
if [ -z "${FIRST_INSTALL}" ]; then
  if [ -f /root/hermes-setup-done.txt ]; then
    FIRST_INSTALL="false"
  else
    FIRST_INSTALL="true"
  fi
fi
