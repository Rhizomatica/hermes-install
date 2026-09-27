# Deploying a network

From nothing to a working network: plan it, create its files, prepare the
central server, install the gateway and the stations, and check that mail
flows both ways.

- [1. Plan](#1-plan)
- [2. Create the network and its station files](#2-create-the-network-and-its-station-files)
- [3. Prepare the central server](#3-prepare-the-central-server)
- [4. Install a station](#4-install-a-station)
- [5. After the install](#5-after-the-install)
- [6. Test the whole chain](#6-test-the-whole-chain)
- [Changing a station later](#changing-a-station-later)

## 1. Plan

Write this down before touching anything; everything below uses it.

| What | Example | Notes |
|---|---|---|
| Network name (`UUCP_NET`) | `PU2UIT` | Letters, digits, `_` and `-`. Names the network's files in `conf/`. |
| Gateway callsign | `PU2UIT` | The gateway's UUCP (and modem) name. Unique among all networks on the central server. |
| Gateway hostname | `estacao.hermes.radio` | Also its mail domain and the name of its station file. |
| Per remote station: callsign, alias, hostname | `PU2UIT-2`, `estacao2`, `estacao2.hermes.radio` | The alias is the station's name in the network's UUCP files. `gw` and `local` are reserved. |
| Radio of each station | sBitx, or a Hamlib CAT radio (e.g. IC-7100, Hamlib model 3070) | See [Station files](station-files.md#radio). |
| Data and voice frequencies | `7480000` Hz, `USB` | Optional: left out, the radio keeps its own. |
| Modem | Mercury | Mercury is free software; VARA needs a license key per network. |
| Transport | UUCP | NNCP is experimental, and all stations of a network must use the same. |

Callsigns must be unique across **all** networks on the central server,
not only within one network: the central server knows every gateway by its
callsign.

Supported hardware today:

- **sBitx on a Raspberry Pi 4**, with `radiod` (hermes-radio-daemon) or the
  older `sbitx_controller`.
- **A Hamlib CAT radio** with a USB sound card, driven by `radiod`.
- **uBITX on a PC** (the original HERMES hardware).

Not yet: the Raspberry Pi 5 (its boot configuration is being prepared), and
a Hamlib radio on a Raspberry Pi goes through the PC path of the system task
(see [Troubleshooting](troubleshooting.md#a-hamlib-radio-on-a-raspberry-pi)).

## 2. Create the network and its station files

The easy way is `hermes-setup`, the installer's menu (it needs `dialog`):

```sh
./hermes-setup
```

1. **New network**: give the network name, the gateway's callsign and the
   central server's VPN address (`10.70.96.1`). It writes the network's three
   files in `conf/`:
   - `sys-gw.<net>`: the gateway's UUCP systems (the central server, the
     gateway itself as `local`, and every remote station);
   - `sys.<net>`: a remote station's UUCP systems (the gateway as `gw`, and
     every remote station);
   - `transport.<net>`: the gateway's mail routing, one line per remote
     station domain.
2. It then offers to write **the gateway's station file**, and to **add
   stations**: for each one it asks every setting that applies to its radio
   and modem, shows the file, and adds the station to the three network
   files.
3. **Show a network** lists its gateway, stations and station files, to
   check the result.

Commit the new files (`stations/*`, `conf/sys.<net>`, `conf/sys-gw.<net>`,
`conf/transport.<net>`) before installing: the stations get them from the
installer checkout.

The files can also be written by hand; copy an existing network and station
file, and see [Station files](station-files.md) for every setting. After
changing a station file by hand, `tests/station_roundtrip.sh <file>` checks
that it still means what you think to the installer.

Adding a station to an existing network later is the same: **New station**
in `hermes-setup`. Every station of the network needs the transport task run
again (see [Changing a station later](#changing-a-station-later)) to learn
the new station.

## 3. Prepare the central server

Once per network, and once per new station. The details, and how to check
them, are in [The central server](central-server.md); in short:

1. **VPN**: a client certificate for each station (`pivpn`), and a fixed
   address for it (`/etc/openvpn/ccd/<hostname>`). Give the station its
   `.ovpn` (see [Deployment files](#deployment-files)).
2. **UUCP** (`/etc/uucp/sys`): the gateway, by callsign, with an alias and its
   VPN address.
3. **Mail routing** (`/etc/postfix/transport`): each station's domain to
   `uucp:<gateway alias>`, then `postmap /etc/postfix/transport`.

DNS needs nothing for `*.hermes.radio`: every name there already points at
the central server. A network under another domain needs its own DNS, TLS
certificate (`conf/ssl/<domain>/`) and mail setup.

## 4. Install a station

On the station (a Raspberry Pi 4 with the sBitx, or a PC):

1. Start from a fresh **Debian 13 (trixie)**: Raspberry Pi OS Lite 64-bit
   (trixie) on the Pi, Debian 13 on a PC. The field guide's USB installer
   image does this step and the next for operators.
2. Get the installer onto it (a checkout of this repository), and run as
   root, from its directory:

   ```sh
   sudo ./hermes-setup      # menu: "Install or reinstall this station"
   ```

   or directly:

   ```sh
   sudo ./installer.sh estacao2.hermes.radio
   ```

   Without a station name, `installer.sh` uses the computer's hostname.
3. The install takes a while (packages, Mercury and the radio daemon are
   built on the station, and the web interface too). `hermes-setup` logs it
   to `/var/log/hermes-installer.log`.
4. Reboot when it finishes.

Useful installer options:

| Option | Effect |
|---|---|
| `--list-tasks` | Lists the installer's tasks, in the order they run |
| `--tasks hermesnet,transport` | Runs only these tasks (the station's secrets are always set up first) |
| `-v` | Installs into a `systemd-nspawn` virtual environment (building images) |
| `HERMES_ERASE_DB=true` | Starts the station's databases over. A reinstall keeps them otherwise |
| `FIRST_INSTALL=true` | Redoes the first-install steps (mail server and webmail configuration) on an installed station, e.g. after a hostname change |

A reinstall is safe on a deployed station. It keeps:

- the databases (messages, users, webmail settings) and mailboxes, applying
  only new database migrations;
- the gateway's `caller.service` as it was (a new gateway gets it enabled);
- every VPN client, unless the station's hostname changes;
- the UUCP startup: the pre-agreed one (`UUCP_PRE_AGREED`) is only used where
  the station file turns it on.

When it has to change the mail transport (the station file asks for another
one), the previous `main.cf` and transport map are kept beside them with the
date, and the installer says so.

## 5. After the install

Check the services (`systemctl is-active <unit>`):

| Unit | Runs on | Does |
|---|---|---|
| `radiod` or `sbitx` | every station | Drives the radio (one of them, never both) |
| `modem` | every station | Mercury (or VARA) |
| `uucpd` | every UUCP station | Answers HF calls, and keys the radio for UUCP |
| `uucp.socket` | every UUCP station | UUCP over TCP |
| `caller` | the gateway | Calls the central server every ~5 minutes, and the stations on the schedules set in the web interface |
| `postfix`, `dovecot` | every station | Mail |
| `openvpn-client@<hostname>` | every station | The VPN (exactly one) |

On the **gateway**, open its web interface and set the call schedules for
its stations: without one, the gateway only calls a station when someone
asks for it. Remote stations call their gateway from their own web
interface. With `UUCP_PRE_AGREED="true"` in the network's station files,
both use the pre-agreed UUCP startup over HF (`uucico -Y`), which makes each
call a minute or more shorter.

## 6. Test the whole chain

Send one mail each way, and follow it.

**Down (Internet to a station)**, from the central server:

```sh
echo "test down" | mail -s "chain test" root@estacao2.hermes.radio
tail -f /var/log/mail.log            # relay=uucp, status=sent: queued for the gateway
```

On the **gateway**, after its next call to the central server (at most about
five minutes):

```sh
sudo uustat -a                                   # a crmail job for the station
sudo uucico -S PU2UIT-2 -Y                       # call the station now, or wait for the schedule
sudo grep PU2UIT-2 /var/log/uucp/Log | tail      # "Login successful (pre-agreed)" ... "Call complete"
```

On the **station**: the mail is in the user's mailbox (webmail, or
`doveadm search -u root@estacao2.hermes.radio subject "chain test"`).

**Up (a station to the Internet)**: send a mail from the station's webmail to
an outside address, then call the gateway from the station's web interface.
The gateway passes it to the central server on its next call; on the central
server, `/var/log/mail.log` shows the delivery and
`DKIM-Signature field added (s=2023, d=hermes.radio)`. At the destination,
the headers should show `dkim=pass` and `dmarc=pass`.

The modem's own log (`journalctl -u modem`) shows each HF session: the
modes used, the SNR each way, retries, and where the time went (the
`[TMG] [arq-timing]` lines).

## Deployment files

A deployment keeps some files with its copy of the installer that must not
be published. Without them the installer still works, as a new deployment
would:

| File | Holds | Without it |
|---|---|---|
| `stations/<hostname>` | the station files | (required: write them with `hermes-setup`) |
| `conf/sys.<net>`, `conf/sys-gw.<net>`, `conf/transport.<net>` | the networks | (required: `hermes-setup` writes them) |
| `conf/passwd` | the networks' UUCP login (`login password`), used by the stations and by `hermes-setup` for new networks | UUCP logins fail: set one |
| `conf/legacy-credentials` | fixed passwords every station gets (pi, WiFi, VNC, databases, mail), for a deployment whose stations share them; see `conf/legacy-credentials.example` | each station gets random ones, printed at the end of its install and kept in `/etc/hermes/secrets` |
| `conf/vpn/` | the stations' `.ovpn` files, as `<hostname>.ovpn` or packed in `keys.tar.gz.gpg` with its passphrase in `conf/vpn/passphrase` | set `VPN_CONFIG_FILE` in the station file to its `.ovpn`; with neither, the station gets no VPN client |
| `conf/ssl/hermes.radio/hermes.radio.key` (and `.crt`) | a certificate shared by the stations | each station makes its own |
| `conf/nncp/pub/` | the stations' NNCP public keys (NNCP networks only) | no NNCP neighbours |

## Changing a station later

| Change | How |
|---|---|
| A setting (frequency, language, options...) | Edit the station file (`hermes-setup`: **Change a station**), commit, and run the installer again with the tasks it concerns |
| Add a station to the network | **New station** in `hermes-setup`, then on every other station of the network run `installer.sh <station> --tasks transport` so they know it, and add it on the central server |
| Turn a station into the gateway | Install it from the **gateway's station file** (e.g. `estacao.hermes.radio`), with `FIRST_INSTALL=true` since its hostname and mail domain change. It gets the gateway's name, callsign, VPN identity and `caller.service`; its old VPN client is switched off |
| Switch a network between UUCP and NNCP | All stations at once (UUCP and NNCP do not talk to each other): set `NNCP_ENABLED` in every station file, commit the stations' NNCP public keys, and reinstall them. Let the UUCP queues empty first: queued mail does not move over |
| Start a station's databases over | `HERMES_ERASE_DB=true` for one run of the installer |
