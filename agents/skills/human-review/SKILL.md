---
name: human-review
description: Run the user's manual review pass over staged changes in Neovim/Fugitive after the automatic `review` skill and before proposing a commit. Looks for REVIEW comments the user leaves in the staged files once they say they're done, then reasons about each one.
---

- **When**: after the `review` skill's findings are triaged, once the change is staged and ready — before proposing a commit. Not a substitute for the automatic review, and not re-run between edits.
- **Precondition**: stage every file intended for this commit (`git add`) first — the review scope is exactly `git diff --staged --name-only`, so anything left unstaged is neither reviewed nor committed.
- **Hand off**: tell the user the files are staged and ready, and to open Neovim and press `<leader>gd` — this opens a dedicated tab with the first staged file in a side-by-side diff split against `HEAD`, reused across the whole pass rather than opening one per file; pressing `<leader>gd` again toggles that tab closed. `<C-n>`/`<C-p>` step to the next/previous staged file (looping) within that same tab. The right-hand pane is the real, editable file on disk. `<leader>gr` inserts a `REVIEW: ` comment (using the buffer's `commentstring`, so it works in any filetype) below the cursor line and drops into insert mode to type the note. Then wait — do not scan for comments until the user says they're finished.
- **Collect**: once the user signals they're done, get the staged file list with `git diff --staged --name-only`, then grep each of those files in the working tree for `REVIEW:`. The comments are unstaged edits on top of the staged diff, so grep the working tree, not the index.
- **Resolve**: for each comment, read the surrounding context and reason about it independently — fix the code when it identifies a real problem, or explain why it doesn't apply when it's mistaken. Either way, remove the `REVIEW:` line once addressed; a leftover marker must never reach a commit. Summarize what was fixed vs. refuted before moving on.
- **Re-stage**: `git add` any files touched while resolving comments, then continue to the commit proposal.
- **No comments found**: proceed straight to the commit proposal.
