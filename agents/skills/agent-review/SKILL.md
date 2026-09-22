---
name: agent-review
description: Second-opinion review of a completed code change by a fresh-context subagent on the default model. Request one review per completed change, before reporting done or proposing a commit — not between edits.
---
- **When**: after completing a code change — once per change, before reporting
  done or proposing a commit. Not between edits, and not a gate to re-run on
  every iteration.
- **Tier**: the default model — the opus tier in Claude Code and Codex. Leave
  the cheapest tier alone, since a review needs real reasoning, and leave the
  premium tier for deliberate escalation on a genuinely high-risk change, where
  its order-of-magnitude cost is earned.
- **Fresh context**: the reviewer must not be you re-reading your own work, so
  spawn a subagent — Claude Code: the Agent tool with `model: opus`; Codex: its
  subagent/task tool; OpenCode: its subagent mechanism. With no subagent
  facility available, run the review as a fresh one-shot against the diff
  rather than reviewing inline.
- **Task spec**: the reviewer sees nothing of this conversation, so it must be
  self-contained — the repository root, the base ref to diff against, and the
  instruction to run `git diff` itself (untracked files count as new-file
  diffs) and review that diff in a single pass. Ask for correctness defects
  first, each with file:line and the concrete failure scenario, then
  simplification and efficiency findings. Calibrated output, no style nits.
- **Triage**: fix or refute every finding before finishing. A finding you
  cannot refute is not resolved by ignoring it.
- **Handoff to the user**: once findings are triaged and the change is staged,
  follow the `human-review` skill for the user's own pass in Neovim before
  proposing a commit.
- **Escalation**: when the same fix has failed twice, or work is thrashing,
  stop re-reviewing and follow the `handoff` skill instead.
