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
