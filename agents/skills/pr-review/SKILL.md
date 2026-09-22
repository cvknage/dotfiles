---
name: pr-review
description: Review another developer's GitHub PR using the same Neovim/Fugitive REVIEW-comment mechanism as `human-review`, then get the comments onto GitHub as a draft the user submits themselves. Never edits the PR's code locally.
---

- **When**: the user asks to review a colleague's PR (by number or URL). Always ask for the
  PR number if not given — never guess which PR to review.
- **Setup**: `gh pr checkout <number>` to fetch and switch to the PR branch, then
  `gh pr view <number> --json baseRefName,headRefOid,url` for the base branch, head commit
  sha, and PR URL.
- **Hand off**: tell the user the PR is checked out, and to start the review in Neovim — it's
  the same review toggle as `human-review`, which switches into PR mode automatically since
  checking out a PR leaves nothing staged: it diffs every changed file against the merge-base
  with the PR's base branch, in one dedicated tab reused across files, with the same
  step/add-comment actions. Then wait — do not scan for comments until the user says they're
  finished.
- **Collect**: once done, for each changed file, `grep -n 'REVIEW:'` the working tree. For
  the i-th match (1-indexed, top to bottom) at raw line L, the real target line is `L - i` —
  each earlier `REVIEW:` line inserted above it shifts everything below down by one. Take the
  text after `REVIEW:` as the comment body.
- **Overall comment**: ask the user whether they want an overall summary comment for the PR
  as a whole, separate from any inline `REVIEW:` notes — a review can carry a top-level body
  alongside, or instead of, per-line comments, and "no inline comments" isn't the same as
  "nothing to say."
- **Nothing to post**: if there are no inline comments and no overall summary, tell the user
  and stop — never post an empty review.
- **Post**: check your skill listing for a work-provided skill that posts automated PR
  reviews to GitHub, and hand it the collected findings (file, line, comment, and any overall
  summary) as additional input, so it folds them into its own combined review rather than
  posting a second, separate one. If no such skill is found, post directly instead: one
  review via `gh api repos/{owner}/{repo}/pulls/<number>/reviews --input -`, JSON body
  `{commit_id, body, comments: [{path, line, side: "RIGHT", body}, ...]}` (`body` the overall
  summary, if any), `commit_id` from the `headRefOid` fetched during setup. Omit the `event`
  field entirely so it lands as a draft (PENDING) review, never auto-submitted — the user
  looks it over and submits it themselves on GitHub.
- **Clean up**: never touch the PR's code. Once the review is posted, remove only the
  `REVIEW:` marker lines from the local working tree — the same annotation-only cleanup as
  `human-review`'s "Resolve" step, without the code fix.
