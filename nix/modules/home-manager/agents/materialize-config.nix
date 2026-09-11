{
  lib,
  pkgs,
}: {
  # Merges nix-managed settings into a writable state file the agent can still
  # mutate (model choice, trust); Home Manager never owns the link. Keys in
  # `authoritativeKeys` are dropped from the state first — the merge only adds
  # and overwrites, so settings removed from the flake would survive forever.
  materializeConfig = {
    format, # "json" or "toml"
    statePath,
    linkPath,
    managedFile,
    authoritativeKeys ? [],
  }: let
    delExpr =
      if authoritativeKeys == []
      then ""
      else "del(${lib.concatStringsSep ", " (map (key: ''.[0]."${key}"'') authoritativeKeys)}) | ";
    # jq speaks JSON only; remarshal bridges TOML configs. A missing or corrupt
    # state file falls back to an empty object rather than failing the switch.
    readStateFile =
      if format == "toml"
      then ''${pkgs.remarshal}/bin/remarshal --if toml --of json < "$state_file" > "$user_file" 2>/dev/null || ${pkgs.coreutils}/bin/printf '{}\n' > "$user_file"''
      else ''${pkgs.coreutils}/bin/cp "$state_file" "$user_file"'';
    readManagedFile =
      if format == "toml"
      then ''${pkgs.remarshal}/bin/remarshal --if toml --of json "$managed_source" > "$managed_file"''
      else ''${pkgs.coreutils}/bin/cp "$managed_source" "$managed_file"'';
    writeStateFile =
      if format == "toml"
      then ''${pkgs.remarshal}/bin/remarshal --if json --of toml "$out_file" > "$final_file"''
      else ''${pkgs.coreutils}/bin/cp "$out_file" "$final_file"'';
  in ''
    state_file=${lib.escapeShellArg statePath}
    link_path=${lib.escapeShellArg linkPath}
    managed_source=${lib.escapeShellArg "${managedFile}"}

    ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$state_file")" "$(${pkgs.coreutils}/bin/dirname "$link_path")"

    # Single-hop symlink to the writable state file: agent config writers resolve one hop only.
    ${pkgs.coreutils}/bin/ln -sfn "$state_file" "$link_path"

    tmp_dir="$(${pkgs.coreutils}/bin/mktemp -d)"
    trap '${pkgs.coreutils}/bin/rm -rf "$tmp_dir"' EXIT

    user_file="$tmp_dir/user.json"
    managed_file="$tmp_dir/managed.json"
    out_file="$tmp_dir/out.json"
    final_file="$tmp_dir/out.final"

    ${pkgs.coreutils}/bin/touch "$user_file"
    if [ -s "$state_file" ]; then
      ${readStateFile}
    fi
    ${pkgs.jq}/bin/jq -e . "$user_file" >/dev/null 2>&1 || ${pkgs.coreutils}/bin/printf '{}\n' > "$user_file"
    ${readManagedFile}

    ${pkgs.jq}/bin/jq -s '${delExpr}.[0] * .[1]' "$user_file" "$managed_file" > "$out_file"

    ${writeStateFile}
    ${pkgs.coreutils}/bin/install -m 0644 "$final_file" "$state_file"
  '';
}
