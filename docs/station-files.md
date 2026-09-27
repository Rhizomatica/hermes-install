# Station files

A station file, `stations/<hostname>`, holds one station's settings. The
installer sources it (it is shell), fills in its own defaults for what the
file leaves out (`common.sh`), and every task reads the result.

`hermes-setup` writes and changes station files, asking only for what
applies to the station's radio and modem. Rewriting a file with it keeps its
meaning (settings it does not know are kept, at the end); run
`tests/station_roundtrip.sh` to check that over every file.

"Default" below is what the installer assumes when the file leaves the
setting out; a new station in `hermes-setup` may start from a different
suggestion.

## Identity and network

| Setting | Example | Default | Meaning |
|---|---|---|---|
| `HERMES_HOSTNAME` | `estacao2.hermes.radio` | required | The station's hostname and mail domain. Also the station file's name and the name of its VPN client. |
| `CALLSIGN` | `PU2UIT-2` | required | UUCP node name, and the modem's callsign. |
| `UUCP_ALIAS` | `estacao2` | required | The station's name in its network's UUCP files. |
| `UUCP_NET` | `PU2UIT` | required | The network: `conf/sys.<net>`, `conf/sys-gw.<net>`, `conf/transport.<net>`. |
| `HERMES_ROLE` | `remote` | required | `remote` or `gateway`. |
| `HERMES_LANGUAGE` | `pt` | required | Web interface language: `en`, `es`, `pt`, `fr`. |
| `TIMEZONE` | `America/Sao_Paulo` | required | A name from `/usr/share/zoneinfo`. |
| `SSL_DOMAIN` | `hermes.radio` | `hermes.radio` | The TLS certificate to use, from `conf/ssl/<domain>/`. |
| `EMERGENCY_EMAIL` | `emergency@hermes.radio` | `emergency@hermes.radio` | Contact shown by the web interface. |
| `HERMES_FWD_EMAIL` | `todos@estacao2.hermes.radio` | `todos@<hostname>` | An address that forwards to every user of the station. |
| `VPN_CONFIG_FILE` | `/root/estacao2.hermes.radio.ovpn` | `conf/vpn/<hostname>.ovpn` | The station's OpenVPN client configuration. With none, the station gets no VPN client. |
| `TLS_SHARED_CERT` | `false` | `true` when `conf/ssl/hermes.radio/hermes.radio.key` exists and hardening is off | `false` makes the station generate its own certificate. |

## Radio

| Setting | Example | Default | Meaning |
|---|---|---|---|
| `HARDWARE` | `sbitx` | required | `sbitx`, `hamlib` (a CAT radio through Hamlib) or `ubitx` (PC). Written as `HARDWARE=${HARDWARE:="sbitx"}`, so the environment can override it. |
| `RADIO_CONTROLLER` | `radiod` | `sbitx_controller` on an sBitx, `radiod` with Hamlib | The program that drives the radio: `radiod` (hermes-radio-daemon) or `sbitx_controller`. Only one runs; installing one replaces the other. |
| `DISPLAY_TYPE` | `v2` | `v1` | sBitx display: `v1` or `v2` (the 7-inch DSI one). |
| `RIG_MODEL` | `3070` | required with `hamlib` | Hamlib model number (`rigctl -l`). |
| `RIG_DEVICE` | `/dev/ttyUSB0` | `/dev/ttyUSB0` | The radio's CAT serial port. |
| `RIG_SERIAL_RATE` | `19200` | `19200` | Serial speed. |
| `RIG_PTT_TYPE` | `RIG` | `RIG` | How to key the radio (Hamlib PTT type). |
| `RIG_AUDIO_DEVICE` | `hw:CODEC,0` | `hw:CODEC,0` | The radio's USB sound card, by ALSA card name. |
| `SOUND_CARD` | `ALC887-VD` | required with `ubitx` | The PC's sound card (`conf/asound.state.<card>`). |
| `INSTALL_FIRMWARE` | `0` | required with `ubitx` | `1` flashes the uBITX firmware during the install. |
| `RADUINO_VER` | `1` | required with `ubitx` | Raduino version: `0`, `1` or `2`. |

## Radio profiles

Profile 0 is data, profile 1 is voice. A frequency or mode left out keeps
what the radio has.

| Setting | Example | Default | Meaning |
|---|---|---|---|
| `DEFAULT_VOICE` | `false` | `false` | `true` starts the radio in the voice profile, and keeps it there. |
| `DEFAULT_DATA_FREQUENCY` | `7480000` | the radio's | Data profile frequency, in Hz. |
| `DEFAULT_DATA_MODE` | `USB` | the radio's | Data profile mode. |
| `DEFAULT_VOICE_FREQUENCY` | `7480000` | the radio's | Voice profile frequency, in Hz. |
| `DEFAULT_VOICE_MODE` | `USB` | the radio's | Voice profile mode. |

## Modem and transport

| Setting | Example | Default | Meaning |
|---|---|---|---|
| `MODEM_TYPE` | `mercury` | `vara` | `mercury` or `vara`. New stations should use Mercury; the default stays VARA so that older station files keep meaning what they did. |
| `VARA_KEY` | | required with `vara` | The network's VARA license key. |
| `NNCP_ENABLED` | `false` | `false` | `true` uses NNCP instead of UUCP (experimental; the whole network must switch). |
| `UUCP_PRE_AGREED` | `true` | `false` | The pre-agreed UUCP startup over HF (`uucpd -F` on every station, `uucico -Y` on calls over the air): about a minute less per call. Needs uucp 1.07-37 or later on **every** station of the network, since a caller using `-Y` cannot reach a station without it. Off by default so that reinstalling one station of a deployed network does not cut it off from the others; turn it on in all of a network's station files once they all have 1.07-37 (`hermes-setup` turns it on for new stations). |

## Options

| Setting | Example | Default | Meaning |
|---|---|---|---|
| `HAS_GPS` | `false` | `false` | A GPS is connected. |
| `GPS_MAP` | `brazil` | `bangladesh` | The map the web interface shows with a GPS. |
| `REQUIRE_LOGIN` | `false` | required | The web interface asks for a login. |
| `HERMES_HARDENING` | `false` | `false` | Random per-station passwords, key-only SSH, the station's own TLS certificate, WPA2/WPA3 WiFi. Off keeps what deployed networks expect. |
| `MAIL_ENCRYPTION` | `true` | `true` | Encrypted mailboxes (Debian 13). |

## Settings for one run

These go in the environment (or, for a one-off, the station file) rather
than staying in the file:

| Setting | Meaning |
|---|---|
| `FIRST_INSTALL` | `true` redoes the first-install steps (mail server and webmail configuration). Detected by the installer; do not keep it in a station file. |
| `HERMES_ERASE_DB` | `true` starts the station's databases over. |
| `HERMES_NET_BRANCH`, `HERMES_RADIO_DAEMON_BRANCH`, `HERMES_API_BRANCH`, `HERMES_GUI_BRANCH` | Install a branch of hermes-net, hermes-radio-daemon, the API or the web interface, to try it before it is merged. Without one, every station gets `main`. |
| `UUCP_BRANCH` | The uucp branch to build when the installed uucp is too old for the pre-agreed startup. |
