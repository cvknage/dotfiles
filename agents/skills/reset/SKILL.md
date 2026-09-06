---
name: reset
description: Clear session state to start a new task. Invoked by the user as /reset.
---
Delete `.agent-sessions/plan.md` and `.agent-sessions/notes.md` at the repository root, then confirm the session state is clear. Do not record anything for the finished task; durable knowledge should already be in the memory graph. Then tell the user to start a fresh session or clear the conversation before the new task.