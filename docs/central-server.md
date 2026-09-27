# The central server

The central server (`hermes.radio`) connects the networks to the Internet:

- **Mail in**: `*.hermes.radio` resolves to it; mail for a station's domain
  is queued there for that network's gateway (`uux`, UUCP over TCP).
- **Mail out**: mail from the stations arrives there from the gateways, and
  leaves DKIM-signed for `hermes.radio` (OpenDKIM, which signs subdomains
  too, so `station.hermes.radio` senders pass DMARC).
- **UUCP**: the gateways call it over the VPN; it never calls out (mail for a
  network waits there until the gateway's next call, every ~5 minutes).
- **VPN**: OpenVPN, `10.70.96.0/24`, the server at `10.70.96.1`; every
  station has a client certificate and a fixed address.

## Per network and per station

### VPN (every station)

1. Create the client (the server uses PiVPN):

   ```sh
   pivpn -a nopass -d 3650 -n estacao2.hermes.radio
   ```

2. Give it a fixed address, unused by any other client:

   ```sh
   echo "ifconfig-push 10.70.96.5 255.255.255.0" > /etc/openvpn/ccd/estacao2.hermes.radio
   ```

3. Give the station the generated `estacao2.hermes.radio.ovpn`: keep it in the
   deployment's `conf/vpn/` (encrypted), or point `VPN_CONFIG_FILE` in the
   station file at it (see
   [Deployment files](deploying-a-network.md#deployment-files)). The installer
   installs the client named after the station's hostname, and switches off
   the client of the station's old hostname when that changes.

### UUCP (every gateway)

In `/etc/uucp/sys`, one entry per gateway, by its callsign (the settings at
the top of the file apply to all):

```
# network bogota
system B0DG
alias cielitabella
address 10.70.96.171
```

Check it with `/usr/lib/uucp/uuchk -s B0DG`.

The callsign must be unique on the server: a remote station of one network
and the gateway of another cannot share a callsign.

### Mail routing (every station)

In `/etc/postfix/transport`, each station's domain, including the
gateway's own, to the gateway's alias:

```
cielitabella.hermes.radio uucp:cielitabella
cielitolindo.hermes.radio uucp:cielitabella
```

then `postmap /etc/postfix/transport`. Check with
`postmap -q cielitolindo.hermes.radio hash:/etc/postfix/transport`.

## Settings that have to stay as they are

| What | Where | Why |
|---|---|---|
| UUCP logins checked by `uucico -l` | `/etc/systemd/system/uucp@.service.d/hermes.conf` | Debian's own `uucp@.service` runs `in.uucpd`, which checks Unix accounts: there is no account for the gateways' UUCP login, so every gateway call fails at the login. A uucp package upgrade puts Debian's unit back; the override survives it. (A 2026 upgrade did exactly this, and no gateway reached the server for weeks.) |
| Port 540 (UUCP) open to the VPN only | `/etc/nftables.conf` | The UUCP login is shared by all gateways. The rule set also drops 3306 (MariaDB), 8891 (the DKIM milter, which signs what it is handed) and 5355 from outside. The VPN interface is matched with `iifname "tun0"` (not `iif`), or the rule set fails to load at boot, before `tun0` exists. |
| `relay_domains = .hermes.radio` | Postfix | Relays the station subdomains only; `hermes.radio` itself is a mailbox domain. |
| `smtpd_reject_unlisted_recipient = yes` | Postfix | Mail to unknown `hermes.radio` users is refused during SMTP instead of bounced to (often forged) senders. |
| `root@`, `uucp@`, `postmaster@`, `abuse@` aliases | `/etc/postfix/virtual_alias` | System mail reaches an administrator instead of bouncing. |
| Weekly rotation of `/var/log/mail.log` | `/etc/logrotate.d/postfix-maillog` | Postfix writes that log itself; nothing else rotates it. |

## Checks

```sh
nft list ruleset | grep "dport 540"            # VPN-only UUCP
systemctl cat uucp@.service | grep ExecStart    # ends with: /usr/sbin/uucico -l
tail /var/log/uucp/Log                          # gateway calls: "Handshake successful", "Call complete"
ls /var/spool/uucp/*/C./                        # mail waiting for each gateway
postqueue -p | tail -1                          # Postfix queue
grep "DKIM-Signature field added" /var/log/mail.log | tail -3
df -h /                                         # the disk; logs and images fill it
```

A gateway that stopped calling shows in `/var/log/uucp/Log` on both ends.
On the gateway, `ERROR: Line disconnected` right after `Calling system
hermes` means the login failed; see
[Troubleshooting](troubleshooting.md#a-gateway-cannot-log-in-to-the-central-server).
