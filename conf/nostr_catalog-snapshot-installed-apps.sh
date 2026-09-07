#!/bin/bash
# Writes /etc/nostr-catalogd/installed-apps.json: every locally installed
# YunoHost app's ID and the packaging repository its catalogue declaration
# names. Runs as root (invoked by nostr_catalog-refresh.service, itself
# root-run by systemd) so that nostr-catalogd itself - which runs
# unprivileged as the nostr_catalog system user - never needs YunoHost API
# access to cross-reference installed apps against catalogue declarations
# for the attestation admin page. The daemon only ever reads this file
# after it has been written.
#
# `app info --full`'s `from_catalog.git.url` (not `manifest.upstream.code`,
# which names the wrapped software's own upstream source, e.g.
# github.com/hzrd149/blossom-server for blossom - a different URL that
# never matches any declaration's `repo` tag) is populated by matching this
# app's id against every catalogue YunoHost knows about, including this
# very Nostr catalogue once it's registered as a custom apps_catalog (see
# catalog_config in _common.sh) - so it already holds exactly the
# packaging-repository URL (e.g. github.com/imattau/blossom_ynh) that
# publishers sign into their declarations.
set -euo pipefail

output_file="/etc/nostr-catalogd/installed-apps.json"
tmp_file="${output_file}.tmp"

install -d -m 0750 -o root -g nostr_catalog "$(dirname "$output_file")"

entries="[]"
for app_id in $(yunohost app list --output-as json | jq -r '.apps[].id'); do
	info_json="$(yunohost app info "$app_id" --full --output-as json 2>/dev/null || true)"
	[ -z "$info_json" ] && continue
	repository="$(printf '%s' "$info_json" | jq -r '.from_catalog.git.url // empty')"
	[ -z "$repository" ] && continue
	entries="$(printf '%s' "$entries" | jq --arg id "$app_id" --arg repo "$repository" '. + [{"app_id": $id, "repository": $repo}]')"
done

printf '{"apps": %s}\n' "$entries" | jq '.' >"$tmp_file"
chown nostr_catalog:nostr_catalog "$tmp_file"
chmod 0640 "$tmp_file"
mv "$tmp_file" "$output_file"
