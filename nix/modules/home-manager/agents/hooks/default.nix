{
  # Shared PostToolUse reindex command for the claude-code and codex modules.
  reindexCommand = "[ -d .code-graph ] && code-graph-mcp incremental-index >/dev/null 2>&1 || true";
}
