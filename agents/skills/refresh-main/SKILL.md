---
name: refresh-main
description: Keep a bare-repo container's default-branch worktree and its code-graph index current, so new worktrees seed from a fresh base. A session-start hook normally starts it; start it yourself only when no message says it is running.
---
A session-start hook normally starts this job: Claude Code and Codex print a "refresh-main is running"
line, and OpenCode prints nothing. When you haven't seen that line, start this skill's
`scripts/refresh-main.py` as a background command, with the bare-repo container as the working
directory: your shell tool's background mode, or `nohup ... &`. Never run it in the foreground and never
wait on it, because it never exits. It does a pass immediately and then every 15 minutes (give a number
of seconds to change that). Starting it again does nothing while one is running.

Each pass fetches, fast-forwards the default branch's worktree only when that worktree is clean (never
stashing, resetting, or discarding), and refreshes that worktree's code-graph index unless a running
server holds it. It touches no other worktree. The first pass after a long gap re-embeds changed code
and can take minutes.

The latest pass's one-line report is in `refresh-main.status` inside the git directory
(`git rev-parse --absolute-git-dir`). Read it when asked how the job is doing. Use
`refresh-main.py --once` to run a single pass in the foreground when debugging.
