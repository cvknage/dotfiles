---
name: handoff
description: Dump session state to the session log so any agent in a fresh session can resume. Use when work is thrashing, the same fix has failed twice, or the user asks to pause or hand off.
---
Append to `.agent-sessions/notes.md`:

- The goal and current plan milestone.
- What was just done.
- The exact next step.
- Open questions and suspicions.

Keep the new content under 30 lines and prune anything resolved or stale. Before handing off, record anything durable — decisions, gotchas, cross-project learnings — in the memory graph via its tools; session state is cleared on reset, the graph is not. Then tell the user to start a fresh session and run the pickup ritual.