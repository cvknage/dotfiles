---
name: spec
description: Write or refresh the session plan for multi-step work. Runs automatically before starting a task that needs milestones; also invoked by the user as /spec.
---
Compose the session plan for the current task; if the task is unclear, ask for it first.

- Break the task into small, independently verifiable milestones; each ends with a concrete done-check (a command, test, or observable result).
- Keep the plan under 100 lines.
- Planning only — do not write code.

Persist it by calling the `write_plan` tool (mcp__sessions__write_plan) with the repository root and the finished plan content — it replaces `.agent-sessions/plan.md` outright, so don't read the old one first. If the tool is unavailable, write `.agent-sessions/plan.md` directly instead.