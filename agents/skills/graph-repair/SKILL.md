---
name: graph-repair
description: Diagnose and refresh a stale or empty code-graph index. Invoked by the user as /graph-repair, or when semantic_code_search/ast_search return empty or stale-looking results.
---
Run `code-graph-mcp health-check` to check index freshness and integrity. If it reports the index is
stale, run `code-graph-mcp incremental-index` to refresh it. If health-check reports a corruption or
integrity failure that incremental-index doesn't resolve, run `code-graph-mcp rebuild-index --confirm`
for a full rebuild. Report what health-check showed and what action was taken.
