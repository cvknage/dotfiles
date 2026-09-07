---
name: pickup
description: Resume recorded work from the session plan and log. Invoked by the user as /pickup.
---
Read the session plan and log via the `agent-sessions` MCP tools (mcp__sessions__read_plan and mcp__sessions__read_notes) with the repository root. In at most five bullets, state where things stand and the exact next step, then continue with it alongside the user's request. If the recorded goal no longer matches what the user asks, say what is unfinished and ask whether to continue or set it aside. If there is no recorded state, do nothing.