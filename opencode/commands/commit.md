---
description: commit staged changes
agent: build
subtask: true
---

Recent commit style reference:
!`git log -n 10 --oneline`

Current staged work:
!`git diff --stat --staged`

Based on the context above, follow these steps:
1. If there are no staged changes, reply exactly with "No staged changes." and do nothing else.
2. Otherwise, produce a concise single-line commit title that mirrors the verbs and tone shown in the recent commit log. Return only the title—no bullets, quotes, fences, or trailing punctuation.
3. After responding with the title, run `git commit -m "$RESPONSE"` and then `git status -sb` to confirm the working tree.
