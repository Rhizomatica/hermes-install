# HERMES installer documentation

Guides for the people who plan, install and run HERMES networks. The field
guide for operators (flashing the USB installer image, wiring the radio,
first e-mail) is in the public
[hermes-documentation](https://github.com/Rhizomatica/hermes-documentation)
repository.

| Guide | For |
|---|---|
| [Deploying a network](deploying-a-network.md) | Planning a network, creating it, installing its gateway and stations, and testing the e-mail chain end to end |
| [Station files](station-files.md) | Every setting of a station file, and what the installer does with it |
| [The central server](central-server.md) | What the central server needs for each network (UUCP, mail routing, VPN), and how to check it |
| [The package repository](package-repository.md) | Publishing packages to `debian.hermes.radio` |
| [Troubleshooting](troubleshooting.md) | Failures seen in the field and on the bench, and how to recognise them |
| [Storage encryption](storage-encryption.md) | Encrypted storage on a station |

## How a HERMES network fits together

```
  Internet                 central server (hermes.radio)
  e-mail  <--- SMTP --->   Postfix + DKIM, UUCP over TCP (port 540, VPN only)
                                      |
                                 OpenVPN (10.70.96.0/24)
                                      |
                           gateway station (HERMES_ROLE="gateway")
                           Postfix, UUCP, caller.service, modem, radio
                                      |
                                 HF radio link (Mercury or VARA)
                                      |
               +----------------------+----------------------+
               |                      |                      |
         remote station         remote station         remote station
         (HERMES_ROLE="remote": Postfix, UUCP, modem, radio, WiFi access point)
```

- **Remote stations** serve their users over WiFi (web interface, webmail,
  Delta Chat) and exchange mail and files with their gateway over HF.
- **The gateway** of a network is a station too, with an Internet uplink:
  it calls the central server over the VPN every few minutes, and calls its
  remote stations over HF on the schedules set in its web interface.
- **The central server** is the network's door to the Internet: mail for
  `station.hermes.radio` arrives there, is queued for the right gateway, and
  mail from the stations leaves from there, DKIM-signed for `hermes.radio`.
- **UUCP** carries mail and files over HF by default. NNCP (encrypted and
  authenticated) is available as an experimental alternative; a network uses
  one or the other, on every station.
