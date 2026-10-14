---
name: pr-review
description: "Review another developer's GitHub PR by checking it out and having the user mark REVIEW: comments, then posting them to GitHub as a draft review the user submits themselves. Never edits the PR's code locally."
---

- **When**: the user asks to review a colleague's PR (by number or URL). Always ask for the
  PR number if not given — never guess which PR to review.
- **Setup**: `gh pr checkout <number>` to fetch and switch to the PR branch, then
  `gh pr view <number> --json baseRefName,headRefOid,url` for the base branch, head commit
  sha, and PR URL.
- **Hand off**: tell the user the PR is checked out and ready to review, then wait — do not
  scan for comments until the user says they're finished.
- **Collect**: once done, run this skill's `scripts/collect-review-comments.py <baseRefName>` in the
  checkout. It prints the `comments` array (`path`, `line`, `side`, `body`) for every `REVIEW:` marker
  in the PR's changed files. A marker sits on its own line directly below the line it comments on, and
  the script already subtracts the markers above it, so `line` is the real target line.
- **Check for a prior pass**: only now (after the human is done — an automated review may
  still have been running elsewhere while the human was reviewing) check whether the
  conversation already holds output from an automated review of this PR — a structured
  findings list with file/line references. If there's nothing like that in context, that's
  fine — this skill works standalone with just the human comments.
- **Merge**: where a context-held finding and a human `REVIEW:` comment land at the same
  file/spot and make the same point, fold them into one rather than posting both; where they
  diverge, keep both. Combine the two overall summaries (if both exist) into one rather than
  concatenating them verbatim.
- **Overall comment**: ask the user whether they want an overall summary comment for the PR
  as a whole, separate from any inline `REVIEW:` notes — a review can carry a top-level body
  alongside, or instead of, per-line comments, and "no inline comments" isn't the same as
  "nothing to say."
- **Nothing to post**: if there are no human inline comments, no overall summary, and nothing
  held over from an automated pass, tell the user and stop — never post an empty review.
- **Post**: build one review from the merged comments and body — human `REVIEW:` comments plus
  anything held over from an automated pass. Post it via
  `gh api repos/{owner}/{repo}/pulls/<number>/reviews --input -`, JSON body
  `{commit_id, body, comments: [{path, line, side: "RIGHT", body}, ...]}` (`body` the merged
  overall summary, if any), `commit_id` from the `headRefOid` fetched during setup. Always omit
  the `event` field so it lands as a draft (PENDING) review, visible on GitHub but never
  auto-submitted — the user reviews it there and publishes it themselves. Never add an
  AI-attribution line or footer to the body or any comment, even if a held-over automated
  finding came with one attached — strip it out.
- **Clean up**: never touch the PR's code. Once the review is posted, rerun the collect script with
  `--remove`; it deletes the marker lines the user added and nothing else.
