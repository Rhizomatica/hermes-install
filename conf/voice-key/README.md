# Voice encryption keys

One file per network, `<UUCP_NET>.key`: the 256-bit key every station of the
network loads for encrypted digital voice, as 64 hex digits.  A station file
with `VOICE_ENCRYPTION="true"` installs its network's key as
`/etc/hermes/voice.key` (mode 0600).

To make one:

    openssl rand -hex 32 > conf/voice-key/<UUCP_NET>.key

Changing a network's key means reinstalling every station of it with the new
file: until then the stations with the old key mute the others' overs.

Encryption is not allowed on amateur bands.
