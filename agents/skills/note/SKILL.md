---
name: note
description: Batch-append findings to .agent-sessions/notes.md. Call once per exploration sweep or milestone, not per observation — combine every pending finding into a single call. Reserve for high-value captures a later session would need: dead ends, non-obvious map knowledge, decisions. Routine observations don't merit a call.
---
Call the `append_note` tool (mcp__sessions__append_note) with the repository root and the full batch of bullets given in the invocation's arguments — write exactly that, don't invent, expand, or split it across multiple calls. The batch is stored under today's date; no need to check for duplicates.