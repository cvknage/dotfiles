state_settings="@mutableSettingsPath@"
state_dir="$(@coreutils@/bin/dirname "$state_settings")"

@coreutils@/bin/mkdir -p "$HOME/.claude"
@coreutils@/bin/mkdir -p "$state_dir"

tmp_dir="$(@coreutils@/bin/mktemp -d)"
user_settings="$tmp_dir/user.json"
managed_settings="$tmp_dir/managed.json"
out_settings="$tmp_dir/out.json"

if [ -e "$state_settings" ]; then
  @coreutils@/bin/cp "$state_settings" "$user_settings"
else
  @coreutils@/bin/printf '{}' > "$user_settings"
fi
@coreutils@/bin/cp "@managedSettingsFile@" "$managed_settings"

if ! @jq@/bin/jq -e . "$user_settings" >/dev/null 2>&1; then
  @coreutils@/bin/printf '{}' > "$user_settings"
fi

# Keys nix owns outright, dropped from the user copy rather than merged. The
# merge below is recursive and only ever adds or overwrites, so without this a
# setting removed from the flake would survive in the mutable file forever.
@jq@/bin/jq -s 'del(.[0].hooks, .[0].permissions, .[0].sandbox) | .[0] * .[1]' \
  "$user_settings" "$managed_settings" > "$out_settings"
@coreutils@/bin/install -m 0644 "$out_settings" "$state_settings"
@coreutils@/bin/rm -rf "$tmp_dir"
