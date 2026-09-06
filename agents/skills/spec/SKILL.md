---
name: spec
description: Write or refresh the session plan for multi-step work. Runs automatically before starting a task that needs milestones; also invoked by the user as /spec.
---
Create or update `.agent-sessions/plan.md` at the repository root for the current task; if the task is unclear, ask for it first.

- Break the task into small, independently verifiable milestones; each ends with a concrete done-check (a command, test, or observable result).
- Keep the plan under 100 lines; replace stale content rather than appending.
- Planning only — do not write code.