---
description: commit staged changes
agent: build
subtask: true
---

Recent commit style reference:
!`git log -n 10 --oneline`

Current staged work (from `git diff --stat --staged`):
!`git diff --stat --staged`

Instructions:
1. If no staged changes, reply exactly: "No staged changes."
2. Otherwise, draft a concise commit message that matches the log style and commit the staged changes.
3. Determine staged state using `git diff --stat --staged`.
