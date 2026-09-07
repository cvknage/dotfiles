---
name: handoff
description: Dump session state to the session log so any agent in a fresh session can resume. Use when work is thrashing, the same fix has failed twice, or the user asks to pause or hand off.
---
Hand off in order:

1. Flush anything learned but not yet recorded — dead ends, decisions, non-obvious map knowledge — by appending it to the session log, so it survives the session.
2. Append the handoff entry to the session log via the `append_note` tool (mcp__sessions__append_note): pass the repository root and a small batch of terse bullets, one per item:
   - The goal and current plan milestone.
   - What was just done.
   - The exact next step.
   - Open questions and suspicions.
   Keep the entry under 30 lines and prune anything resolved or stale.
3. Record anything durable — gotchas, cross-project learnings — in the memory graph via its tools. Session state is cleared on reset; the graph is not.
4. Tell the user to start a fresh session and run the pickup ritual.