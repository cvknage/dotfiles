---
name: recap
description: Plain-language summary of what a finished plan milestone changed, so the user knows where things stand before review. Run automatically after a milestone's done-check passes and before `agent-review`, and whenever the user asks what changed or where we are.
---
- **When**: a milestone's done-check has passed, before `agent-review`; or the user asks what changed or where we ended. Once per milestone, not between edits.
- **Gather** (read, don't paste): the plan and notes via `read_plan` and `read_notes`; `git status --short` and `git diff HEAD --stat`; untracked files count as new. Open the diff only for the areas you need to describe. In a herdr worktree, run git with `-C <target-dir>` and read the agent's report with `read_notes` on `<target-dir>`; the full plan and your own notes stay on your repo root.
- **Write it for a reader who didn't follow the work.** Short sentences, everyday words, say what a thing does before its name, no unexplained acronyms. Only state what the diff or a run shows; say "not checked" otherwise.
- **Shape**, about 25 lines at most:
  1. **Goal / this milestone**: one sentence each.
  2. **What changed**: grouped by purpose, one line each, paths in brackets. Say what it does now, not the history.
  3. **Different from the plan**: what we did differently and why, or "nothing".
  4. **Does it work**: the done-check result. Run it if it hasn't been run.
  5. **Look here first**: 3–5 `file:line` spots, in the order to read them.
  6. **Left to do**: open questions and what the next milestone starts with.
- **Keep the plan honest**: using what this milestone taught, make the next milestone self-contained (goal, constraints, done-check) and fix any later rough ones, with `revise_plan`. Say what changed in one line. Never rewrite an already detailed milestone's goal or done-check without telling the user.
- **Record it**: append 3–5 bullets of the summary with `append_note` so a fresh session knows where we ended.
- **Then** continue the Review Flow (`agent-review`, `human-review`, commit proposal).
