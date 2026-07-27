{
  config,
  inputs,
  lib,
  pkgs,
  repoScopes,
  ...
}: let
  sharedPermissions = import ../agents/command-permissions.nix;
  permissionsLib = import ../agents/permissions-lib.nix {inherit lib;};
  codexCliPackage = inputs.codex-cli.packages.${pkgs.stdenv.hostPlatform.system}.codex;

  codexRules = permissionsLib.mkCodexExecPolicyRules sharedPermissions;

  packageVersion =
    if config.programs.codex.package != null
    then lib.getVersion config.programs.codex.package
    else "0.94.0";

  isTomlConfig = lib.versionAtLeast packageVersion "0.2.0";
  settingsFormat =
    if isTomlConfig
    then pkgs.formats.toml {}
    else pkgs.formats.yaml {};
  useXdgDirectories = config.home.preferXdgDirectories && isTomlConfig;
  xdgConfigHome = lib.removePrefix config.home.homeDirectory config.xdg.configHome;
  configDir =
    if useXdgDirectories
    then "${xdgConfigHome}/codex"
    else ".codex";
  configFileName =
    if isTomlConfig
    then "config.toml"
    else "config.yaml";
  mutableConfigPath = "${config.xdg.stateHome}/codex/${configFileName}";

  pythonEnv = pkgs.python3.withPackages (ps: [
    ps."tomli-w"
    ps.pyyaml
  ]);

  mcpServers =
    lib.mapAttrs (
      _name: server:
      # TOML has no null; strip null-valued attrs (e.g. unset `url`/`enabled`)
      # that the mcp module leaves in place, or serialization fails with
      # "unsupported unit type".
        lib.filterAttrs (_: v: v != null) (
          (lib.removeAttrs server [
            "disabled"
            "headers"
          ])
          // (lib.optionalAttrs (server ? headers && !(server ? http_headers)) {
            http_headers = server.headers;
          })
          // {
            default_tools_approval_mode = "approve";
            enabled = !(server.disabled or false);
          }
        )
    )
    config.programs.mcp.servers;

  settings =
    {
      approval_policy = "on-request";
      features.child_agents_md = true;
      suppress_unstable_features_warning = true;
      sandbox_mode = "workspace-write";
      sandbox_workspace_write.writable_roots = repoScopes;
    }
    // lib.optionalAttrs config.programs.mcp.enable {
      mcp_servers = mcpServers;
    };

  managedSettingsFile = settingsFormat.generate "codex-managed-config" settings;

  materializeConfigPy = pkgs.writeText "codex-materialize-config.py" ''
    from __future__ import annotations

    import os
    from copy import deepcopy
    from pathlib import Path

    import tomli_w
    import yaml

    state_path = Path(os.environ["STATE_CONFIG"])
    managed_path = Path(os.environ["MANAGED_CONFIG"])
    out_path = Path(os.environ["OUT_CONFIG"])
    config_format = os.environ["CODEX_CONFIG_FORMAT"]


    def load_config(path: Path):
        if not path.exists() or path.stat().st_size == 0:
            return {}

        try:
            if config_format == "toml":
                import tomllib

                with path.open("rb") as handle:
                    return tomllib.load(handle) or {}

            with path.open("r", encoding="utf-8") as handle:
                return yaml.safe_load(handle) or {}
        except Exception:
            return {}


    def merge(user_value, managed_value):
        if isinstance(user_value, dict) and isinstance(managed_value, dict):
            merged = dict(user_value)
            for key, value in managed_value.items():
                merged[key] = merge(merged.get(key), value) if key in merged else deepcopy(value)
            return merged

        return deepcopy(managed_value)


    managed_config = load_config(managed_path)
    user_config = load_config(state_path)
    merged_config = merge(user_config, managed_config)

    if config_format == "toml":
        out_path.write_text(tomli_w.dumps(merged_config), encoding="utf-8")
    else:
        out_path.write_text(yaml.safe_dump(merged_config, sort_keys=False), encoding="utf-8")
  '';

  materializeConfig = pkgs.writeShellApplication {
    name = "codex-materialize-config";
    runtimeInputs = [
      pkgs.coreutils
      pythonEnv
    ];
    text = ''
            set -euo pipefail

            state_config="${mutableConfigPath}"
            state_dir="$(${pkgs.coreutils}/bin/dirname "$state_config")"
            managed_config="${managedSettingsFile}"
            tmp_dir="$(${pkgs.coreutils}/bin/mktemp -d)"
            user_config="$tmp_dir/user.${configFileName}"
            out_config="$tmp_dir/out.${configFileName}"

            trap '${pkgs.coreutils}/bin/rm -rf "$tmp_dir"' EXIT

            ${pkgs.coreutils}/bin/mkdir -p "$state_dir"

            if [ -e "$state_config" ]; then
              ${pkgs.coreutils}/bin/cp "$state_config" "$user_config"
            else
              ${pkgs.coreutils}/bin/touch "$user_config"
            fi

            export STATE_CONFIG="$user_config"
            export MANAGED_CONFIG="$managed_config"
      export OUT_CONFIG="$out_config"
      export CODEX_CONFIG_FORMAT="${
        if isTomlConfig
        then "toml"
        else "yaml"
      }"

      ${pythonEnv}/bin/python "${materializeConfigPy}"

      ${pkgs.coreutils}/bin/install -m 0644 "$out_config" "$state_config"
    '';
  };
in {
  home.file."${configDir}/${configFileName}" = lib.mkForce {
    source = config.lib.file.mkOutOfStoreSymlink mutableConfigPath;
  };

  home.activation.codexMaterializeConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    ${materializeConfig}/bin/codex-materialize-config
  '';

  programs.codex = {
    enable = true;
    package = codexCliPackage;
    rules = {
      "shared-bash-permissions" = codexRules;
    };
    inherit settings;
  };
}
