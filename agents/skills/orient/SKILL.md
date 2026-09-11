---
name: orient
description: Orient in unfamiliar code using memory and code-graph before reading files sequentially. Invoked by the user as /orient, or before starting work in an unfamiliar module.
---
Before reading files sequentially to understand an unfamiliar module or codebase: first consult
`memory` via `mcp__memory__search_nodes` for durable, cross-session knowledge about this project
(decisions, gotchas, architecture) -- run the `harvest` skill first if `memory` doesn't know this
project yet. Then, if a `code-graph` MCP server is connected for this project (or run
`code-graph-mcp health-check` from Bash), use it in this order: `mcp__code-graph__project_map`/
`code-graph-mcp map` for the overall architecture, `mcp__code-graph__module_overview`/
`code-graph-mcp overview <path>` for a specific directory or file's symbols, then
`mcp__code-graph__ast_search`/`mcp__code-graph__semantic_code_search` to find a specific concept or
symbol by concept rather than exact name. Fall back to Glob/Grep/Read only for what neither covers
-- see `agents/AGENTS.md`'s Code Navigation section for what to trust and what not to.
