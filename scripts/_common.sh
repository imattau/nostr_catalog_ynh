#!/bin/bash

app="nostr_catalog"
install_dir="/var/lib/nostr-catalogd"
env_file="/etc/nostr-catalogd/nostr-catalogd.env"
service_name="$app"

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
