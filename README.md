# nostr_catalog_ynh

YunoHost wrapper for the Nostr-backed YunoHost application catalogue.

This repository packages and configures `nostr-catalogd` as a normal YunoHost
application. The daemon consumes signed declarations, applies local trust and
curation policy, verifies repositories, caches accepted metadata, and serves a
YunoHost-compatible `/v3/apps.json` endpoint.

The wrapper does not replace YunoHost installation or app lifecycle tooling.

## Status

Initial packaging scaffold. Install/remove/upgrade scripts and the YunoHost
configuration panel are next.

The initial configuration panel is now defined in `config_panel.toml`; install
scripts must render its stored values into `/etc/nostr-catalogd/nostr-catalogd.env`.

## Core dependency

Release binaries are produced by the
[`nostr-yunohost`](https://github.com/nostr-yunohost/nostr-yunohost) core
repository. The package should pin a core release and verify its checksum.
