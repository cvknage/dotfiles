---
name: handoff
description: Dump session state to the session log so any agent in a fresh session can resume. Use when work is thrashing, the same fix has failed twice, or the user asks to pause or hand off.
---
Compose a handoff entry covering:

- The goal and current plan milestone.
- What was just done.
- The exact next step.
- Open questions and suspicions.

Keep it under 30 lines and prune anything resolved or stale. Before handing off, record anything durable — decisions, gotchas, cross-project learnings — in the memory graph via its tools; session state is cleared on reset, the graph is not.

Persist the handoff entry by calling the `append_note` tool (mcp__sessions__append_note) with the repository root and the composed entry as a single bullet (it appends to `.agent-sessions/notes.md` under today's date). If the tool is unavailable, append to `.agent-sessions/notes.md` directly instead.

Then tell the user to start a fresh session and run the pickup ritual.