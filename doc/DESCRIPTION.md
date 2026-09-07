Nostr Catalogue replaces the centralised discovery and publication layer
behind YunoHost's app catalogue with a decentralised one built on
[Nostr](https://nostr.com). Publishers sign and broadcast app declarations
(repository, commit, manifest and content hashes) to relays instead of
submitting them to a single maintained list; this server's daemon,
`nostr-catalogd`, consumes those declarations, applies local trust and
attestation policy, verifies the referenced repository itself, and serves a
standard YunoHost-compatible `/v3/apps.json` custom catalogue.

Installation, upgrades, and app lifecycle management stay completely normal
YunoHost operations - Nostr never executes application code, it only carries
signed metadata about where to find it and what to trust.

Administrators choose which publishers to trust (`trusted_publishers`), and
optionally require CI-backed attestations - signed, machine-checkable claims
that a specific commit passed automated checks - before a package is offered
for install (`attestation_policy`). A server can also endorse apps it has
installed from another publisher's declaration, using its own catalogue
identity, from the admin trust dashboard.

This package installs the daemon itself, not an application to browse or use
directly - it exposes the catalogue endpoint YunoHost's own app store reads
from, plus an admins-only trust dashboard for reviewing publishers,
attestations, and endorsements.
