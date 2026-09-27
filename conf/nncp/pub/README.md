# NNCP public keys

One file per station, named like the station file in `stations/`
(for example `conf/nncp/pub/estacao2.hermes.radio`).

Each station creates its own keys during installation. Its private keys stay
in `/etc/nncp/self/` on the station and must never be committed. The
installer writes the public keys to `/etc/nncp/<station_name>.pub`; copy that
file here and commit it.

Stations in the same `UUCP_NET` are configured as a full mesh: after new
public keys are committed, update the installer checkout on each station of
that network and run

    hermes-nncp-mesh <station_name> <installer_dir>
    systemctl restart nncp-daemon

Format:

    id: ...
    exchpub: ...
    signpub: ...
    noisepub: ...
