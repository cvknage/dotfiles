---
name: harvest
description: Build or refresh the memory graph for the current project. Invoked by the user as /harvest, or when they ask to index, learn, or onboard a project.
---
Populate the memory MCP server with durable knowledge about the repository in the current working directory.

- Create or reuse one entity for the project (`mcp__memory__create_entities`; name: the repository's name, type: project), with observations for its purpose, stack, build/test commands, and origin URL.
- Explore entry points, configs, and recent git history enough to extract durable knowledge: architecture, key components, decisions and their reasons, gotchas, non-obvious workflows.
- Record each item as an entity with dated observations and pointer paths, linked to the project entity with a `belongs_to` relation via `mcp__memory__create_relations`. Never write project knowledge without that link.
- Search the graph first via `mcp__memory__search_nodes`; add observations to existing entities (`mcp__memory__add_observations`) instead of creating duplicates, and delete or correct anything reality contradicts.
- Durable knowledge only — no volatile values, no task state. Depth over volume.
