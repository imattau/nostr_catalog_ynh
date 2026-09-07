#!/bin/bash
# Writes /etc/nostr-catalogd/installed-apps.json: every locally installed
# YunoHost app's ID and declared upstream repository URL. Runs as root
# (invoked by nostr_catalog-refresh.service, itself root-run by systemd) so
# that nostr-catalogd itself - which runs unprivileged as the nostr_catalog
# system user - never needs YunoHost API access to cross-reference installed
# apps against catalogue declarations for the attestation admin page. The
# daemon only ever reads this file after it has been written.
set -euo pipefail

output_file="/etc/nostr-catalogd/installed-apps.json"
tmp_file="${output_file}.tmp"

install -d -m 0750 -o root -g nostr_catalog "$(dirname "$output_file")"

entries="[]"
for app_id in $(yunohost app list --output-as json | jq -r '.apps[].id'); do
	info_json="$(yunohost app info "$app_id" --full --output-as json 2>/dev/null || true)"
	[ -z "$info_json" ] && continue
	repository="$(printf '%s' "$info_json" | jq -r '.manifest.upstream.code // empty')"
	[ -z "$repository" ] && continue
	entries="$(printf '%s' "$entries" | jq --arg id "$app_id" --arg repo "$repository" '. + [{"app_id": $id, "repository": $repo}]')"
done

printf '{"apps": %s}\n' "$entries" | jq '.' >"$tmp_file"
chown nostr_catalog:nostr_catalog "$tmp_file"
chmod 0640 "$tmp_file"
mv "$tmp_file" "$output_file"
