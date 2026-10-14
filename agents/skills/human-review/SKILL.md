---
name: human-review
description: Run the user's manual review pass over staged changes after the automatic `agent-review` skill and before proposing a commit. Looks for REVIEW comments the user leaves in the staged files once they say they're done, then reasons about each one.
---

- **When**: after the `agent-review` skill's findings are triaged, once the change is staged and ready — before proposing a commit. Not a substitute for the automatic review, and not re-run between edits.
- **Precondition**: stage every file intended for this commit (`git add`) first — the review scope is exactly `git diff --staged --name-only`, so anything left unstaged is neither reviewed nor committed.
- **Hand off**: tell the user the files are staged and ready to review, then wait — do not
  scan for comments until the user says they're finished.
- **Collect**: once the user signals they're done, run this skill's `scripts/collect-review-comments.py`. It lists every `REVIEW:` comment the user added to the staged files, as `path:line: text` plus the code line it comments on. A marker sits on its own line directly below the line it comments on. `REVIEW:` text already in the staged content, such as documentation that mentions the marker, is not listed.
- **Resolve**: for each comment, read the surrounding context and reason about it independently — fix the code when it identifies a real problem, or explain why it doesn't apply when it's mistaken. Once every comment is addressed, run the script with `--remove`, which deletes the marker lines and nothing else; a leftover marker must never reach a commit. Summarize what was fixed vs. refuted before moving on.
- **Re-stage**: `git add` any files touched while resolving comments, then continue to the commit proposal.
- **No comments found**: proceed straight to the commit proposal.
