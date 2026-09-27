# Troubleshooting

Failures seen on the bench and in the field, and how to recognise them.

## Mail

### A gateway cannot log in to the central server

On the gateway, `/var/log/uucp/Log`:

```
Calling system hermes (port TCP)
ERROR: Line disconnected
```

and on the central server, `journalctl` shows
`pam_unix(uucp:auth): check pass; user unknown`. The central server is
running Debian's `in.uucpd`, which checks Unix accounts, instead of
`uucico -l`. Restore the override described in
[The central server](central-server.md#settings-that-have-to-stay-as-they-are).
The installer installs the same override on the stations.

### Mail from a station sits queued and never leaves

Check where Postfix sends it: `postconf default_transport` must be
`uucp:gw` on a remote station and `uucpmx:gw` on a gateway (with UUCP). A
station switched from NNCP to UUCP by an old installer kept `nncp:gw`, and
`nncp-exec` accepted mail that nothing would ever send. The installer now
sets the transport on every run.

### The gateway never calls

`systemctl is-active caller` on the gateway. Gateways installed before the
installer enabled `caller.service` have it disabled: enable it, or run the
installer again. Calls to the stations also need schedules in the gateway's
web interface.

### Mail to a station bounces with "User unknown"

The station's Postfix maps are rebuilt from Dovecot's user list on every
install. If a station was installed with maps left empty, run the installer
again (the email task).

## Installing

### A reinstall lost the station's messages and users

Installers before 2026-09 dropped the databases on every other run. A
reinstall now keeps them; `HERMES_ERASE_DB=true` starts them over on
purpose.

### Two VPN tunnels on one station

A station reinstalled under another hostname kept its old VPN client
enabled. The installer now switches off the client of the station's old
hostname when the hostname changes (and nothing otherwise); on an older
install, `systemctl disable --now openvpn-client@<old name>`.

### A Hamlib radio on a Raspberry Pi

The system task treats every `HARDWARE` other than `sbitx` as a PC (GRUB,
i386 packages, no Raspberry Pi boot configuration). Until the installer
tells the computer apart from the radio, a Hamlib station on a Raspberry Pi
needs its base system prepared by hand.

## Radio and modem

### Every loopback period is 288 frames and the station is deaf

The radio controller was restarted under a running modem, and the ALSA
loopback cards took the modem's period size. `hermes-radio.service` (the
controller) must start before `modem.service`; restart the controller, which
restarts the modem after it.

### HF sessions are slow

`journalctl -u modem` shows each session. Mercury's `[TMG] [arq-timing]`
lines give the connect time, every turnaround, the modes and SNR in each
direction, and the disconnect. On a healthy link, most of a small mail's
time goes to turnarounds rather than data. Check that both ends use the
pre-agreed startup: `/var/log/uucp/Log` says `Login successful
(pre-agreed)`.
