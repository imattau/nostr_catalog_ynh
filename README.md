# nostr_catalog_ynh

YunoHost wrapper for the Nostr-backed YunoHost application catalogue.

This repository packages and configures `nostr-catalogd` as a normal YunoHost
application. The daemon consumes signed declarations, applies local trust and
curation policy, verifies repositories, caches accepted metadata, and serves a
YunoHost-compatible `/v3/apps.json` endpoint.

The wrapper does not replace YunoHost installation or app lifecycle tooling.

Wrapper metadata and the systemd template are checked in CI on every change.

## Status

Packaging scaffold with manifest, configuration panel, daemon environment
renderer, systemd service, and lifecycle scripts. The first core binary
release is now published and pinned in `manifest.toml`.

The configuration panel stores settings through YunoHost and renders them into
`/etc/nostr-catalogd/nostr-catalogd.env`; the daemon reads those settings at
startup.

## Core dependency

Release binaries are produced by the
[`nostr-yunohost`](https://github.com/nostr-yunohost/nostr-yunohost) core
repository. The package should pin a core release and verify its checksum.
The core release workflow publishes `SHA256SUMS` alongside the
architecture-specific archives; the wrapper should copy the matching digest
into its `resources.sources.main` entry.
The wrapper pins the matching `nostr-catalogd` archive for each supported
architecture in `manifest.toml`, and its lifecycle scripts install, upgrade,
and remove the daemon around `ynh_setup_source`.
