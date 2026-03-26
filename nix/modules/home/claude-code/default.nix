{
  config,
  lib,
  pkgs,
  repoScopes,
  ...
}: let
  sharedPermissions = import ../agents/command-permissions.nix;
  permissionsLib = import ../agents/permissions-lib.nix {inherit lib;};

  scopedPathRules = permissionsLib.mkClaudeScopedPathRules repoScopes;

  fileAccessRules = lib.flatten (map (dir: [
      "Read(${dir}/**)"
      "Edit(${dir}/**)"
      "Write(${dir}/**)"
    ])
    repoScopes);

  hookScript = pkgs.writeShellApplication {
    name = "claude-code-deny-outside-repo-scopes";
    runtimeInputs = [pkgs.jq pkgs.python3];
    text = ''
      input="$(cat)"
      tool_name="$(printf '%s' "$input" | jq -r '.tool_name // empty')"
      command="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
      file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
      cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"

      repo_scopes=(
        ${lib.concatStringsSep "\n" (map (scope: "\"${scope}\"") repoScopes)}
      )

      if [[ -z "$cwd" ]]; then
        echo "Blocked: Missing working directory" >&2
        exit 2
      fi

      cwd_real="$(python -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$cwd")"

      in_scope=false
      for scope in "''${repo_scopes[@]}"; do
        scope_real="$(python -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$scope")"
        if [[ "$cwd_real" == "$scope_real" || "$cwd_real" == "$scope_real"/* ]]; then
          in_scope=true
          break
        fi
      done

      if [[ "$in_scope" == false ]]; then
        echo "Blocked: Command executed outside repo scopes" >&2
        exit 2
      fi

      if [[ "$tool_name" == "Bash" ]]; then
        if [[ -z "$command" ]]; then
          exit 0
        fi

        if [[ "$command" == "cd" || "$command" == "cd "* || "$command" == *" cd "* || "$command" == "pushd "* || "$command" == *" pushd "* || "$command" == "popd"* || "$command" == *" popd "* || "$command" == "dirs"* || "$command" == *" dirs "* ]]; then
          echo "Blocked: Changing directories is not allowed" >&2
          exit 2
        fi

        if [[ "$command" == *"../"* ]]; then
          echo "Blocked: Bash command uses parent directory traversal" >&2
          exit 2
        fi

        if [[ "$command" == *"$"* ]]; then
          echo "Blocked: Bash command uses env var expansion" >&2
          exit 2
        fi

        if [[ "$command" == *";"* ]]; then
          echo "Blocked: Bash command uses semicolons (use && or || for chaining)" >&2
          exit 2
        fi

        repo_scopes_joined="$(printf '%s\n' "''${repo_scopes[@]}")"
        REPO_SCOPES="$repo_scopes_joined" CWD="$cwd" COMMAND="$command" \
          python - <<'PY'
      import os
      import shlex
      import sys

      command = os.environ.get("COMMAND", "")
      cwd = os.environ.get("CWD", "")
      scopes = [s for s in os.environ.get("REPO_SCOPES", "").splitlines() if s]

      try:
        tokens = shlex.split(command)
      except ValueError:
        print("Blocked: Unable to parse command", file=sys.stderr)
        sys.exit(2)

      def in_scope(path):
        for scope in scopes:
          if path == scope or path.startswith(scope + os.sep):
            return True
        return False

      def candidate_path(value):
        stripped = value.lstrip("<>")
        if not stripped or stripped.startswith("-"):
          return None
        if stripped.startswith("~"):
          return os.path.expanduser(stripped)
        if os.path.isabs(stripped):
          return stripped
        if stripped.startswith(".") or "/" in stripped:
          return os.path.join(cwd, stripped)
        return None

      for token in tokens:
        value = token
        if "=" in token and not token.startswith("="):
          _, value = token.split("=", 1)
        path = candidate_path(value)
        if path:
          real_path = os.path.realpath(path)
          if not in_scope(real_path):
            print(f"Blocked: Path outside repo scopes: {value}", file=sys.stderr)
            sys.exit(2)

      sys.exit(0)
      PY

        exit 0
      fi

      if [[ "$tool_name" == "Read" || "$tool_name" == "Edit" || "$tool_name" == "Write" ]]; then
        if [[ -z "$file_path" ]]; then
          echo "Blocked: Missing file path" >&2
          exit 2
        fi

        REPO_SCOPES="$(printf '%s\n' "''${repo_scopes[@]}")" FILE_PATH="$file_path" \
          python - <<'PY'
      import os
      import sys

      file_path = os.environ.get("FILE_PATH", "")
      scopes = [s for s in os.environ.get("REPO_SCOPES", "").splitlines() if s]

      real_path = os.path.realpath(os.path.expanduser(file_path))
      for scope in scopes:
        if real_path == scope or real_path.startswith(scope + os.sep):
          sys.exit(0)

      print("Blocked: File path outside repo scopes", file=sys.stderr)
      sys.exit(2)
      PY

        exit 0
      fi

      exit 0
    '';
  };

  # Persist Claude settings in a writable location so Claude Code can mutate settings.json
  # for plugin install/management.
  mutableSettingsPath = "${config.xdg.stateHome}/claude/settings.json";

  settings = {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    # defaultMode = "dontAsk";
    hooks = {
      PreToolUse = [
        {
          matcher = "Bash|Read|Edit|Write";
          hooks = [
            {
              type = "command";
              command = "${hookScript}/bin/claude-code-deny-outside-repo-scopes";
            }
          ];
        }
      ];
    };
    inherit permissions;
  };

  managedSettingsFile = pkgs.writeText "claude-code-settings.json" (builtins.toJSON settings);

  permissions = {
    allow =
      (permissionsLib.mkClaudeBashPermissions sharedPermissions).allow
      ++ scopedPathRules
      ++ fileAccessRules;
    ask = (permissionsLib.mkClaudeBashPermissions sharedPermissions).ask;
    deny = (permissionsLib.mkClaudeBashPermissions sharedPermissions).deny;
    additionalDirectories = repoScopes;
  };
in {
  # Override the store-backed Home Manager settings.json with an out-of-store symlink to a
  # writable file. Claude Code can then update settings during plugin install.
  #
  # Important: use the exact target path Home Manager uses (relative to $HOME) to avoid
  # conflicting target definitions.
  home.file.".claude/settings.json" = lib.mkForce {
    source = config.lib.file.mkOutOfStoreSymlink mutableSettingsPath;
  };

  home.activation.claudeCodeMaterializeSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # Path to the mutable settings file that ~/.claude/settings.json symlinks to.
    # Kept in $XDG_STATE_HOME so Claude Code and plugins can write to it at runtime.
    state_settings="${mutableSettingsPath}"
    state_dir="$(${pkgs.coreutils}/bin/dirname "$state_settings")"

    # Ensure both the config dir and the state dir exist before writing.
    ${pkgs.coreutils}/bin/mkdir -p "$HOME/.claude"
    ${pkgs.coreutils}/bin/mkdir -p "$state_dir"

    # Work in a temp dir so the merge is atomic — the state file is never
    # left in a partially-written state if something goes wrong mid-merge.
    tmp_dir="$(${pkgs.coreutils}/bin/mktemp -d)"
    user_settings="$tmp_dir/user.json"    # current on-disk settings (may include plugin writes)
    managed_settings="$tmp_dir/managed.json"  # Nix-controlled settings baked into the store
    out_settings="$tmp_dir/out.json"      # merged result

    # Seed user_settings from the existing state file, or start with an empty
    # object on first run (e.g. fresh machine, no prior settings).
    if [ -e "$state_settings" ]; then
      ${pkgs.coreutils}/bin/cp "$state_settings" "$user_settings"
    else
      ${pkgs.coreutils}/bin/printf '{}' > "$user_settings"
    fi
    ${pkgs.coreutils}/bin/cp "${managedSettingsFile}" "$managed_settings"

    # Guard against a corrupt/non-JSON state file (e.g. truncated mid-write).
    # Reset to {} so the merge still produces a valid result.
    if ! ${pkgs.jq}/bin/jq -e . "$user_settings" >/dev/null 2>&1; then
      ${pkgs.coreutils}/bin/printf '{}' > "$user_settings"
    fi

    # Merge: user settings are the base, managed settings win on conflict.
    # This means Nix-controlled keys (hooks, permissions) always take effect,
    # while user/plugin keys not present in managed (e.g. statusLine) are preserved.
    ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$user_settings" "$managed_settings" > "$out_settings"
    # Atomically replace the state file and set safe permissions (0644).
    ${pkgs.coreutils}/bin/install -m 0644 "$out_settings" "$state_settings"
    ${pkgs.coreutils}/bin/rm -rf "$tmp_dir"
  '';

  programs.claude-code = {
    enable = true;
    enableMcpIntegration = true;
    inherit settings;
  };
}
