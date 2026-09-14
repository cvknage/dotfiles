---
name: review
description: Second-opinion review of a completed code change by a fresh-context subagent at the standard tier. Request one review per completed change, before reporting done or proposing a commit — not between edits.
---
- **When**: after completing a code change — once per change, before reporting
  done or proposing a commit. Not between edits, and not a gate to re-run on
  every iteration.
- **Tier**: the standard one. The premium tier (fable/kimi) costs an order of
  magnitude more and exists for deliberate escalation on a genuinely high-risk
  change, not for routine review; the cheapest tier is wrong too, since a
  review needs real reasoning.
- **Fresh context**: the reviewer must not be you re-reading your own work, so
  spawn a subagent — Claude Code: the Agent tool with `model: sonnet`; Codex:
  its subagent/task tool; OpenCode: its subagent mechanism. With no subagent
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
- **Escalation**: when the same fix has failed twice, or work is thrashing,
  stop re-reviewing and follow the `handoff` skill instead.
