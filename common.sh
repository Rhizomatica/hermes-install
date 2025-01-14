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
