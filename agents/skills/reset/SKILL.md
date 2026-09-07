---
name: reset
description: Clear session state to start a new task. Invoked by the user as /reset.
---
Call the `reset_session` tool (mcp__sessions__reset_session) with the repository root, then confirm the session state is clear. If the tool is unavailable, delete the entire `.agent-sessions/` directory directly instead. Do not record anything for the finished task; durable knowledge should already be in the memory graph. Then tell the user to start a fresh session or clear the conversation before the new task.