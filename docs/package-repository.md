# The package repository

The stations install HERMES packages (Mercury, uucp, csdr, qt-kiosk-browser,
...) from `http://debian.hermes.radio/hermes`, suite `trixie`, for `amd64`
and `arm64`, signed with the "HERMES APT Repo" key (`hermes.key` at the
repository root).

The repository is managed with **reprepro, the Debian trixie package**
(`5.4.6+really5.3.2`). Use that version everywhere: a database made by a
newer reprepro cannot be read by trixie's. Trixie's reprepro keeps one
version per package in the indices; older files stay in `pool/`.

On the repository server, the reprepro state (configuration and database)
lives in a directory whose `conf/options` points `outdir` at the published
tree, so it works in place.

## Publishing a package

1. Build the package for both architectures from the same source package
   (amd64 on a PC, arm64 on a Raspberry Pi with trixie), with its build
   dependencies installed (`apt-get build-dep` or the list in
   `debian/control`).
2. On the repository server, with the signing key in the keyring of the user
   running reprepro:

   ```sh
   reprepro -b <state dir> --ignore=unknownfield includedsc trixie foo_1.0-1.dsc
   reprepro -b <state dir> --ignore=unknownfield includedeb trixie foo_1.0-1_amd64.deb foo_1.0-1_arm64.deb
   ```

   reprepro copies the files into `pool/`, and exports and signs the indices.
3. Check from a station:

   ```sh
   apt-get update && apt-cache policy foo    # the new version as candidate
   ```

Packages whose control file has no `Section` need one at include time
(`-S otherosfs -P optional` for the hangover libraries).

## A package built from a fork with changes in the tree

Some packages (uucp, for example) are maintained as a fork whose changes
are committed directly to the source tree, with `3.0 (quilt)` and an empty
patch series. Once the repository has an `orig.tar.gz` for the upstream
version, a later revision cannot replace it (same name, different content),
and a plain source build then fails with "local changes detected". Build the
source package from the repository's orig tarball, letting dpkg-source record
the tree's changes as one patch:

```sh
git archive <commit> | tar x -C build/uucp-1.07
cp <repository>/pool/main/u/uucp/uucp_1.07.orig.tar.gz build/
cd build/uucp-1.07
dpkg-buildpackage -S -d -us -uc --source-option=--auto-commit
```

Then build the binaries from that source package (`dpkg-source -x`, then
`dpkg-buildpackage -b`), so that both architectures come from the same
source. `dpkg-source -x` of the result gives back the git tree exactly.
