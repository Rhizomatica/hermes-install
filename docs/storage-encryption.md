# Storage encryption on a station (activity 3)

Design note for the APC security grant (SG2026-106, activity "SD Card
Encryption"). Written to be implemented by someone other than its author:
if a decision below looks wrong, it probably is — say so before coding.

## What this protects, and what it does not

A station is a Raspberry Pi with an SD card, often in a place where it can be
taken: a health post, a school, a house in a village. Today everything on that
card is readable by anyone who takes it — mail, the mail database, the NNCP
spool, and the station's private keys.

Encryption at rest protects **a station that is switched off**, and copies of
its storage (a card taken out, an image made of it, a discarded card).

It does **not** protect a station that is running and taken while powered, nor
a station where the attacker has root. That is honest and worth writing in the
report as such.

## Constraints that shape the design

1. **Images are built with `HERMES-tools`, not sdm.** `image_installer.sh`
   prepares one image per station and `prepare_image.sh` shrinks it; both need
   a plaintext ext4 (`e4defrag`, `zerofree`, `resize2fs`). So the image cannot
   ship encrypted.
2. **One image is written to many cards.** Anything encrypted at build time
   would share one key across stations, which is the mistake we just finished
   removing from the installer. The key must be generated on the station.
3. **A station must boot unattended.** Power cuts are routine and nobody is
   there to type a passphrase. So the root filesystem stays plaintext and the
   station always reaches a state where it can be reached over SSH or the radio.
4. **Images are built to a 30 GB rootfs.** On a 32 GB card there is almost no
   unallocated space left; on a 64 GB card there is plenty. The implementation
   has to cope with both.

## Shape of the solution

Encrypt the station's **data**, not its operating system: a LUKS2 volume
mounted at `/var`, created on the station at first boot with a key generated
there.

    /dev/mmcblk0p1  /boot/firmware   plaintext (unchanged)
    /dev/mmcblk0p2  /                plaintext (unchanged)
    LUKS2 volume    /var             mail, database, NNCP spool, GUI data

Where the LUKS volume lives, decided at first boot:

- **A third partition**, when the card has at least `VAR_MIN_FREE` (suggest
  8 GB) unallocated after partition 2. Preferred: no loop device, no file on a
  filesystem that is itself being emptied.
- **A container file** (`/var.luks`, size `VAR_SIZE`) on the root filesystem
  when there is not enough unallocated space. Works everywhere, costs a loop
  device and some performance.

### The keys are not all in /var

`/var` covers mail (`/var/mail`), the database (`/var/lib/mysql`), the NNCP
spool (`/var/spool/nncp`) and the web data. It does **not** cover:

| Path | Contents | Decision |
|---|---|---|
| `/etc/nncp/` + `/etc/nncp.hjson` | the station's NNCP private keys | **must be protected**: move to `/var/lib/nncp/` and symlink, or bind-mount from `/var`. Otherwise a stolen card yields the radio identity and the ability to decrypt captured traffic. |
| `/etc/hermes/secrets` | per-station passwords | same: move under `/var` and symlink. |
| `/etc/hermes/mailcrypt`, `mail-recovery.pem` | marker and recovery certificate | marker can stay; the certificate is public. |
| `/etc/ssl/private/hermes.radio.key` | station TLS key | worth moving; a stolen key lets someone impersonate the station's web interface. |

Do this **before** enabling encryption on real stations, or the feature gives
less than it appears to. Note the ordering problem: `nncp-daemon` and the mail
services must start only after `/var` is unlocked (`RequiresMountsFor=/var`),
and the key-bearing paths must be symlinks by then.

## Unlocking

Station file sets `VAR_KEY_MODE`:

- **`usb` (default).** The volume key is a key file on a USB stick that stays
  with the radio, found by partition label (`HERMESKEY`) or UUID. The station
  boots, mounts it, unlocks `/var`, and continues. Someone who takes the card
  alone gets nothing; someone who takes the whole station including the stick
  gets everything — which is the honest limit, and still better than today.
- **`passphrase`.** Nothing is stored. `/var` stays locked until an
  administrator unlocks it over SSH or the VPN
  (`systemd-cryptsetup attach` / `cryptsetup open`). Services that need `/var`
  wait. Correct for the highest-risk stations, wrong for a station nobody
  visits.

Both need a way back:

- A **second LUKS keyslot** holding a recovery passphrase, generated on the
  station, encrypted to the administrator's certificate
  (`/etc/hermes/mail-recovery.pem`, as the mailbox keys already do) and stored
  off the station. `cryptsetup luksAddKey`.
- Optionally, that same blob shipped to the gateway over NNCP, the way the
  audit log is.

## First-boot flow

A oneshot unit (`hermes-encrypt-var.service`, `ConditionPathExists` on a
marker) that is idempotent and safe to interrupt:

1. Refuse to run unless `ENCRYPT_STORAGE=true` and the marker is absent.
2. Choose partition or container file, per free space.
3. Generate the volume key (`/dev/urandom`), write it per `VAR_KEY_MODE`.
4. `cryptsetup luksFormat` (LUKS2, argon2id), open as `hermes-var`.
5. `mkfs.ext4`, mount at `/var.new`, `rsync -aHAX /var/ /var.new/` with the
   services stopped.
6. Add the recovery keyslot; encrypt and store the recovery blob.
7. Write `/etc/crypttab` and `/etc/fstab`; add `RequiresMountsFor=/var` drop-ins.
8. Create the marker, reboot, verify `/var` is the LUKS volume and only then
   delete the old contents.

If any step fails, stop and leave the station exactly as it was. A station that
boots unencrypted is a bug report; a station that does not boot is a field trip.

## Packages to add

`cryptsetup`, `cryptsetup-bin` (`tasks/system_setup.sh` `PACKAGES`). Root
encryption is **not** in scope, so `cryptsetup-initramfs` and
`dropbear-initramfs` are not needed.

## Station file flags

| Flag | Default | Meaning |
|---|---|---|
| `ENCRYPT_STORAGE` | `false` | opt in per station |
| `VAR_KEY_MODE` | `usb` | `usb` or `passphrase` |
| `VAR_SIZE` | `8G` | container size when no partition is possible |
| `VAR_MIN_FREE` | `8G` | unallocated space needed to prefer a partition |

## Tests before this goes near a partner station

- Raspberry Pi 4 and 5, 32 GB card (container path) and 64 GB card (partition path).
- Reboot with the USB key present; reboot with it absent (station must still boot,
  `/var` locked, SSH reachable).
- Power cut during step 5 (the copy) and during step 8 (the swap).
- Recovery passphrase opens the volume on another machine.
- A station upgraded from an unencrypted install, with mail already in `/var`.
- Mail, NNCP and the web interface work after the reboot; `nncp-daemon` did not
  start before `/var` was unlocked.
- `lsblk`, `cryptsetup status hermes-var` and `findmnt /var` say what we think.

## Open questions

1. Move the key-bearing paths under `/var` (symlinks) or bind-mount them? The
   symlink is simpler; the bind-mount keeps paths honest for anything that
   writes to `/etc` expecting a real file.
2. Is the USB stick realistic for the partner stations, or does `passphrase`
   plus a visit become the default for the high-risk ones?
3. Do we encrypt the swap file as well, if there is one?
4. Should the recovery blob go to the gateway over NNCP by default, or only
   when the administrator asks?
