{
  agentPolicy,
  agentSandbox,
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  codexCliPackage = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex;
  sandboxedCodexCli = agentSandbox.wrapPackage {
    agent = "codex";
    package = codexCliPackage;
    executable = "codex";
  };

  settingsFormat = pkgs.formats.toml {};
  xdgConfigHome = lib.removePrefix config.home.homeDirectory config.xdg.configHome;
  configDir =
    if config.home.preferXdgDirectories
    then "${xdgConfigHome}/codex"
    else ".codex";
  configFileName = "config.toml";
  mutableConfigPath = "${config.home.homeDirectory}/${configDir}/.mutable/${configFileName}";
  legacyMutableConfigPath = "${config.xdg.stateHome}/codex/${configFileName}";

  pythonEnv = pkgs.python3.withPackages (ps: [ps."tomli-w"]);

  mcpServers =
    lib.mapAttrs (
      _: server:
      # TOML has no null; strip null-valued attrs (e.g. unset `url`/`enabled`)
      # that the mcp module leaves in place, or serialization fails with
      # "unsupported unit type".
        lib.filterAttrs (_: v: v != null) (
          (lib.removeAttrs server [
            "disabled"
            "headers"
          ])
          # Codex rejects http_headers on stdio servers, even when empty, and the
          # mcp module defaults `headers` to {} for every server.
          // (lib.optionalAttrs
            (!(server ? http_headers)
              && (server.headers or null) != null
              && server.headers != {}) {
              http_headers = server.headers;
            })
          // {
            enabled = !(server.disabled or false);
            default_tools_approval_mode = "approve";
          }
        )
    )
    config.programs.mcp.servers;

  settings =
    agentPolicy.codex.settings
    // {
      features.child_agents_md = true;
      suppress_unstable_features_warning = true;
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

    state_path = Path(os.environ["STATE_CONFIG"])
    managed_path = Path(os.environ["MANAGED_CONFIG"])
    out_path = Path(os.environ["OUT_CONFIG"])

    # Keys nix owns outright, replaced rather than merged. The merge below only
    # ever adds and overwrites, so without this a server dropped from the flake
    # would survive in the mutable config forever.
    AUTHORITATIVE_KEYS = (
        "approval_policy",
        "default_permissions",
        "mcp_servers",
        "permissions",
        "sandbox_mode",
        "sandbox_workspace_write",
    )


    def load_config(path: Path):
        if not path.exists() or path.stat().st_size == 0:
            return {}

        try:
            import tomllib

            with path.open("rb") as handle:
                return tomllib.load(handle) or {}
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

    if isinstance(user_config, dict):
        for key in AUTHORITATIVE_KEYS:
            user_config.pop(key, None)

    merged_config = merge(user_config, managed_config)

    out_path.write_text(tomli_w.dumps(merged_config), encoding="utf-8")
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
      elif [ -e "${legacyMutableConfigPath}" ]; then
        # Preserve mutable settings from the previous state-directory layout.
        ${pkgs.coreutils}/bin/cp "${legacyMutableConfigPath}" "$user_config"
      else
        ${pkgs.coreutils}/bin/touch "$user_config"
      fi

      export STATE_CONFIG="$user_config"
      export MANAGED_CONFIG="$managed_config"
      export OUT_CONFIG="$out_config"

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
    package = sandboxedCodexCli;
    rules = {
      "shared-bash-permissions" = agentPolicy.codex.rules;
    };
    inherit settings;
  };
}
