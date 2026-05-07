# hermes-install

This is the HERMES system installer for HERMES' "gateway" and "remote"
stations. 

The installer works for the sBitx radio, where this installer
will work on any Debian 12 arm64 OS, like the Raspberry Pi OS. 
Support for Debian 12 amd64 (x86_64) is temporarilly disabled, and will be fixed soon.


The syntax is simple, just run as root from this repository's directory:

* ./installer.sh station.hermes.radio

where "station.hermes.radio" should be substituted by the station name.

Check stations/ directory for station setup profiles.

# How to create a new setup

This repository comes with station setup samples. There is a
self-signed SSL key for convenience - please substitute it 
for a valid key for production use. 

# SSL Certificate

A self-signed SSL certificate for `hermes.radio` is provided in
`conf/ssl/hermes.radio/` for testing and development purposes.
It is valid until May 2046.

For production use, replace these files with a valid certificate:

```
conf/ssl/hermes.radio/hermes.radio.crt   # your certificate
conf/ssl/hermes.radio/hermes.radio.key   # your private key
```

Alternatively, set `SSL_DOMAIN` in your station profile to use a
different domain, and place your certificate and key at:

```
conf/ssl/your-domain.com/your-domain.com.crt
conf/ssl/your-domain.com/your-domain.com.key
```

The certificate will be installed to:
- `/etc/ssl/certs/hermes.radio.crt` (nginx)
- `/etc/ssl/private/hermes.radio.key` (nginx)
- `/etc/dovecot/ssl/mailserver.crt` → symlink
- `/etc/dovecot/ssl/mailserver.key` → symlink