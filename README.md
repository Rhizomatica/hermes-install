# hermes-install

The installer of HERMES stations, "gateway" and "remote": it turns a
Debian 13 (trixie) computer with an HF radio into a HERMES station. It
supports the sBitx on a Raspberry Pi 4 (Raspberry Pi OS Lite 64-bit,
trixie), CAT radios through Hamlib, and the uBITX on a PC.

## Quick start

As root, from this repository's directory:

```sh
./hermes-setup                          # menus: networks, station files, install
./installer.sh station1.hermes.radio    # or install a station directly
```

`hermes-setup` (it needs `dialog`) creates a network and its station files,
asking for every setting, and installs a station with the tasks you choose.
`installer.sh --list-tasks` lists the installer's tasks, and
`--tasks a,b` runs only those.

`stations/` has sample station files (a gateway, `center.hermes.radio`, and
two stations of the `example` network, `conf/sys.example`,
`conf/sys-gw.example` and `conf/transport.example`).

## Documentation

See [docs/](docs/README.md): deploying a network (planning, creating it,
installing the gateway and stations, testing the mail chain), every station
file setting, the central server, the package repository, and
troubleshooting.

## Before deploying

This repository holds no credentials. A deployment adds its own (see
[Deployment files](docs/deploying-a-network.md#deployment-files)):

- `conf/passwd`: the stations' UUCP login. It ships as `user change-me`:
  change it.
- `conf/legacy-credentials` (optional, format in
  `conf/legacy-credentials.example`): fixed passwords for every station.
  Without it, each station gets random ones, printed at the end of its
  install and kept in `/etc/hermes/secrets`.
- The stations' VPN client configurations: `VPN_CONFIG_FILE` in the station
  file, or `conf/vpn/`. Without one, a station gets no VPN client.

## SSL certificate

A self-signed certificate for `hermes.radio` is provided in
`conf/ssl/hermes.radio/` for testing and development. It is valid until May
2046.

For production, replace these files with a valid certificate:

```
conf/ssl/hermes.radio/hermes.radio.crt   # your certificate
conf/ssl/hermes.radio/hermes.radio.key   # your private key
```

Alternatively, set `SSL_DOMAIN` in your station file to use another domain,
and place its certificate and key at:

```
conf/ssl/your-domain.com/your-domain.com.crt
conf/ssl/your-domain.com/your-domain.com.key
```

Without a certificate's key, or with `HERMES_HARDENING="true"`, each station
generates its own. The certificate is installed to:

- `/etc/ssl/certs/hermes.radio.crt` (nginx)
- `/etc/ssl/private/hermes.radio.key` (nginx)
- `/etc/dovecot/ssl/mailserver.crt` → symlink
- `/etc/dovecot/ssl/mailserver.key` → symlink
