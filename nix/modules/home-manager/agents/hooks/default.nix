{dotfiles}: let
  refreshMainPath = "${dotfiles}/agents/skills/refresh-main/scripts/refresh-main.py";
in {
  # Shared PostToolUse reindex command for the claude-code and codex modules.
  reindexCommand = "[ -d .code-graph ] && code-graph-mcp incremental-index >/dev/null 2>&1 || true";

  inherit refreshMainPath;

  # SessionStart command for the claude-code and codex modules.
  refreshMainCommand = ''
    [ "$(git rev-parse --is-bare-repository 2>/dev/null)" = true ] && [ -x "${refreshMainPath}" ] && {
      nohup "${refreshMainPath}" >/dev/null 2>&1 &
      echo "refresh-main is running in the background; its latest report is in $(git rev-parse --absolute-git-dir)/refresh-main.status"
    } || true
  '';
}
