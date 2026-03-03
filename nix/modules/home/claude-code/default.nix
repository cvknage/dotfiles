{
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

        if [[ "$command" == *";"* || "$command" == *"|"* || "$command" == *"&"* || "$command" == *"<"* || "$command" == *">"* || "$command" == *"\`"* || "$command" == *"\$("* ]]; then
          echo "Blocked: Bash command uses shell operators" >&2
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
  programs.claude-code = {
    enable = true;
    enableMcpIntegration = true;
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
  };
}
