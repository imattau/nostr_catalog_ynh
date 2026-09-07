#!/bin/bash

app="${YNH_APP_ID}"
install_dir="/var/lib/nostr-catalogd"
env_file="/etc/nostr-catalogd/nostr-catalogd.env"
service_name="$app"
refresh_service_name="${app}-refresh"
refresh_timer_name="${app}-refresh.timer"
refresh_service_path="/etc/systemd/system/${refresh_service_name}.service"
refresh_timer_path="/etc/systemd/system/${refresh_timer_name}"
catalog_config="/etc/yunohost/apps_catalog.yml"
publisher_key_file="/etc/nostr-catalogd/publisher.key"
publisher_npub_file="/etc/nostr-catalogd/publisher.npub"
installed_apps_file="/etc/nostr-catalogd/installed-apps.json"
snapshot_script_path="/etc/nostr-catalogd/snapshot-installed-apps.sh"

install_refresh_timer() {
	install -m 0644 "$(dirname "$0")/../conf/nostr_catalog-refresh.service" "$refresh_service_path"
	install -m 0644 "$(dirname "$0")/../conf/nostr_catalog-refresh.timer" "$refresh_timer_path"
	install -m 0750 "$(dirname "$0")/../conf/nostr_catalog-snapshot-installed-apps.sh" "$snapshot_script_path"
	systemctl daemon-reload
	systemctl enable --now "$refresh_timer_name"
	# The timer's own first run is OnBootSec=10min away (and won't fire again
	# until next boot within that window on an already-running system) - kick
	# it off now so the attestation admin page isn't empty until then. Must
	# go through systemctl (out-of-process), not a direct call: this install/
	# upgrade script is itself running inside a live yunohost operation, and
	# the snapshot script's own `yunohost app list`/`app info` calls would
	# nest inside that same lock and fail near-instantly.
	trigger_refresh
}

trigger_refresh() {
	systemctl start --no-block "$refresh_service_name" || true
}

remove_refresh_timer() {
	systemctl disable --now "$refresh_timer_name" || true
	rm -f "$refresh_timer_path" "$refresh_service_path" "$snapshot_script_path"
	systemctl daemon-reload
}

normalize_key_list() {
	printf '%s\n' "$1" |
		awk '{ gsub(/,/, " "); for (i = 1; i <= NF; i++) print $i }' |
		paste -sd, -
}

display_key_list() {
	normalize_key_list "$1" | tr ',' '\n'
}

unpack_core_release() {
	if [ ! -f "$install_dir/main" ]; then
		return 0
	fi
	tar --extract --gzip --file="$install_dir/main" --directory="$install_dir"
	rm -f "$install_dir/main"
}

ensure_publisher_key() {
	# The key files live outside the install_dir and may not exist on a fresh
	# install. Create their parent directory before install(1) opens them.
	# Group-owned by $app (not just root:root) so the daemon's own service
	# user can traverse into it to read publisher.key and installed-apps.json
	# directly - file-level permissions still gate the actual content.
	install -d -m 0750 -o root -g "$app" "$(dirname "$publisher_key_file")"
	if [ -s "$publisher_key_file" ] && [ -s "$publisher_npub_file" ]; then
		# The always-running daemon (User=nostr_catalog) now reads this file
		# itself to sign attestations in-process, where previously only
		# root-run config-panel actions (scripts/config's run__publish) ever
		# opened it. Fix ownership on every install/upgrade, not just when
		# the key is first generated below, so upgrades of existing
		# installs (root:root 0600 from before this feature) also become
		# readable by the service user.
		chown "$app:$app" "$publisher_key_file" "$publisher_npub_file"
		return 0
	fi
	local keygen_output
	keygen_output="$(mktemp)"
	if ! "$install_dir/nostr-ynh" keygen >"$keygen_output"; then
		rm -f "$keygen_output"
		ynh_die "Could not generate the catalogue publisher identity"
	fi
	install -m 0600 /dev/null "$publisher_key_file"
	install -m 0644 /dev/null "$publisher_npub_file"
	jq -er .private_key_hex "$keygen_output" >"$publisher_key_file"
	jq -er .npub "$keygen_output" >"$publisher_npub_file"
	chown "$app:$app" "$publisher_key_file" "$publisher_npub_file"
	rm -f "$keygen_output"
}

update_catalog_registration() {
	local action="$1"
	python3 - "$catalog_config" "$action" <<'PY'
import os
import sys
import tempfile

import yaml

path, action = sys.argv[1:]
default = [{"id": "default", "url": "https://app.yunohost.org/default"}]

if os.path.exists(path):
    with open(path, encoding="utf-8") as handle:
        catalogs = yaml.safe_load(handle) or []
else:
    catalogs = default

if not isinstance(catalogs, list):
    raise SystemExit(f"{path} must contain a YAML list")
catalogs = [entry for entry in catalogs if isinstance(entry, dict) and entry.get("id") != "nostr"]
if action == "add":
    catalogs.append({"id": "nostr", "url": "http://127.0.0.1:8090"})
elif catalogs == default:
    if os.path.exists(path):
        os.unlink(path)
    raise SystemExit(0)

directory = os.path.dirname(path)
fd, temporary = tempfile.mkstemp(prefix="apps_catalog.", dir=directory, text=True)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        yaml.safe_dump(catalogs, handle, default_flow_style=False, sort_keys=False)
    os.chmod(temporary, 0o640)
    os.replace(temporary, path)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)
PY
}

render_daemon_env() {
	local relays trusted_publishers trusted_curators minimum_endorsements
	relays="$(ynh_app_setting_get --app="$app" --key=relays)"
	trusted_publishers="$(ynh_app_setting_get --app="$app" --key=trusted_publishers)"
	trusted_curators="$(ynh_app_setting_get --app="$app" --key=trusted_curators)"
	minimum_endorsements="$(ynh_app_setting_get --app="$app" --key=minimum_endorsements)"
	minimum_endorsements="${minimum_endorsements:-1}"
	if ! [[ "$minimum_endorsements" =~ ^[1-9][0-9]*$ ]]; then
		ynh_die "minimum_endorsements must be a positive integer"
	fi

	install -d -m 0750 "$(dirname "$env_file")"
	{
		printf 'NOSTR_YNH_RELAYS=%s\n' "$relays"
		printf 'NOSTR_YNH_TRUSTED_PUBLISHERS=%s\n' "$trusted_publishers"
		printf 'NOSTR_YNH_TRUSTED_CURATORS=%s\n' "$trusted_curators"
		printf 'NOSTR_YNH_MINIMUM_ENDORSEMENTS=%s\n' "$minimum_endorsements"
	} >"$env_file"
	chmod 0640 "$env_file"
}
