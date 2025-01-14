# to be run from hermes-installer
#
#

DELTACHAT_APK_URL="https://download.delta.chat/android/deltachat-gplay-release-1.46.14.apk"
DELTACHAT_DEB_URL="https://download.delta.chat/desktop/v1.46.8/deltachat-desktop_1.46.8_amd64.deb"
DELTACHAT_WIN_URL="https://download.delta.chat/desktop/v1.46.8/DeltaChat Setup 1.46.8.exe"
DELTACHAT_MAC_URL="https://download.delta.chat/desktop/v1.46.8/DeltaChat-1.46.8-universal.dmg"


do_deltachat_download()
{

## SEPARATE THIS...
    echo -e "${Red}COPYING DELTACHAT BINARIES${Color_Off}"

    cd ${TMP_PATH}
    # rm -f deltachat* DeltaChat*
    mkdir -p ${DELTACHAT_DOWNLOAD_PATH}

    if [ ! -f "$(basename "${DELTACHAT_WIN_URL}")" ]; then
        wget "${DELTACHAT_WIN_URL}"
    fi
    install -C -g www-data -o www-data -m 644 "$(basename "${DELTACHAT_WIN_URL}")" "${DELTACHAT_DOWNLOAD_PATH}/$(basename "${DELTACHAT_WIN_URL}")"
    install -C -g www-data -o www-data -m 644 "$(basename "${DELTACHAT_WIN_URL}")" "${DELTACHAT_DOWNLOAD_PATH}/deltachat.exe"

    if [ ! -f "$(basename "${DELTACHAT_DEB_URL}")" ]; then
        wget "${DELTACHAT_DEB_URL}"
    fi
    install -C -g www-data -o www-data -m 644 "$(basename "${DELTACHAT_DEB_URL}")" "${DELTACHAT_DOWNLOAD_PATH}/$(basename "${DELTACHAT_DEB_URL}")"
    install -C -g www-data -o www-data -m 644 "$(basename "${DELTACHAT_DEB_URL}")" "${DELTACHAT_DOWNLOAD_PATH}/deltachat.deb"

    if [ ! -f "$(basename "${DELTACHAT_MAC_URL}")" ]; then
        wget "${DELTACHAT_MAC_URL}"
    fi
    install -C -g www-data -o www-data -m 644 "$(basename "${DELTACHAT_MAC_URL}")" "${DELTACHAT_DOWNLOAD_PATH}/$(basename "${DELTACHAT_MAC_URL}")"
    install -C -g www-data -o www-data -m 644 "$(basename "${DELTACHAT_MAC_URL}")" "${DELTACHAT_DOWNLOAD_PATH}/deltachat.dmg"

    if [ ! -f "$(basename "${DELTACHAT_APK_URL}")" ]; then
        wget "${DELTACHAT_APK_URL}"
    fi
    install -C -g www-data -o www-data -m 644 "$(basename "${DELTACHAT_APK_URL}")" "${DELTACHAT_DOWNLOAD_PATH}/$(basename "${DELTACHAT_APK_URL}")"
    install -C -g www-data -o www-data -m 644 "$(basename "${DELTACHAT_APK_URL}")" "${DELTACHAT_DOWNLOAD_PATH}/deltachat.apk"


}
