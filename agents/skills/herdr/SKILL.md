---
name: herdr
description: Launch another coding-agent instance in its own `herdr` pane, hand it a self-contained task, and supervise it to completion -- including noticing when it's blocked on a permission/approval prompt and deciding whether to respond. Use when a task should run as a separate, possibly long-running or prompt-heavy agent instance instead of blocking the current session. Generic orchestration only; the target task comes from whatever skill or instructions you put in the prompt you hand the spawned agent.
---

Drives `herdr` (https://herdr.dev) to run a second agent instance hands-off. Pure orchestration --
the task itself comes from the prompt you send in step 3.

Commands go through a local proxy, not the real herdr socket. It accepts fewer things than the
plain `herdr` CLI docs describe; follow the exact forms below, not `--help` output.

## 1. Preconditions

- `command -v herdr` -- if missing, tell the user.
- `[ -n "$HERDR_SOCKET_PATH" ]` -- if unset, tell the user herdr isn't available this session.
  Don't run `herdr status server` to check instead; it will not give a useful answer here.

## 2. Give the agent a pane

Two separate names, every time, whether this is one agent or several sharing an assignment -- never
conflate them:

- An **assignment name**, picked once up front. This is always the tab/workspace label, from its very
  first creation call -- never an individual agent's own name, even when there's only one agent.
- An **agent name** per spawned agent instance (aim for under 20-30 characters; the hard cap is 100),
  used as its `agent start` name in step 3 and as its own pane's label (below) -- never the tab/
  workspace label.

If `$HERDR_WORKSPACE_ID` is set, create a tab in it (shows up next to you):

```
herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd <target-dir> --label "<assignment-name>"
```

Otherwise, create a workspace:

```
herdr workspace create --cwd <target-dir> --label "<assignment-name>"
```

`<target-dir>` must be under a root you're already scoped to.

Need the agent in its own branch and checkout instead of sharing your cwd? Create it yourself first,
the same way you'd run any other git command, choosing `<target-dir>` under a root you're already
scoped to (and can write to):

```
git worktree add -b <branch-name> --no-track <target-dir> [<base-ref>]
```

`--no-track`: the sandbox keeps `.git/config` read-only, so if `<base-ref>` is a remote-tracking ref
(e.g. `origin/main`), git's default auto-tracking setup fails to write the new tracking config --
usually harmlessly (the worktree is still created), but it prints a confusing
"could not write config file" error and a false "set up to track" message. `--no-track` avoids both.

Then point `workspace create`/`tab create` at `<target-dir>` exactly as above. In step 5, after (not
before) closing the pane with `workspace close`/`tab close`, also run `git worktree remove
<target-dir>` yourself to delete the checkout -- closing the pane only closes herdr's own state.

Take the pane id (`root_pane.pane_id`) and the tab/workspace id (for step 5's teardown) from the
output, then label the pane with this agent's own name:

```
herdr pane rename <pane_id> "<agent-name>"
```

Running several agents on one shared assignment? Give each additional one a pane in the SAME tab or
workspace instead of a separate one, splitting off any pane already in it (the first agent's root pane
works), then label the new pane with its own agent's name the same way -- the tab/workspace label never
changes, since it was already the assignment name from the start:

```
herdr pane split <pane_id> --direction right|down
herdr pane rename <new_pane_id> "<agent-name>"
```

`<new_pane_id>` is `pane.pane_id` from the split's own output (not `root_pane.pane_id` -- that field
only appears on workspace/tab creation). Repeat step 3 for it.

Need to rename the assignment itself later? `herdr tab rename <tab_id> "<assignment-name>"` or
`herdr workspace rename <workspace_id> "<assignment-name>"`.

## 3. Start the agent and hand it a task

```
herdr agent start <agent-name> --kind <your-own-kind> --pane <pane_id> [-- <agent-cli-args>]
herdr agent prompt <pane_id> "<task>" --wait --timeout <ms>
```

- `<agent-name>` -- this agent's own name from step 2 (the same one used for `pane rename`, not the
  assignment name), for herdr's own registration.
- `--kind` -- must be your own agent kind; anything else is rejected.
- `--pane <pane_id>` -- the pane id from step 2.
- `[-- <agent-cli-args>]` -- extra CLI args passed to the agent binary itself.

Target every later command by `<pane_id>`, never `<agent-name>`. The prompt must be plain text, no
control bytes or ANSI escapes. The spawned agent has zero context: brief it like a fresh subagent,
including what "done" looks like. `--wait` returns at `idle`/`done`/`blocked`/timeout.

## 4. Supervise it

`blocked` means herdr detected an approval/question UI -- not that the request is safe to approve.

1. `herdr agent read <pane_id> --source recent` before anything else.
2. Approve only read-only/idempotent actions inside the task's stated scope. For anything
   destructive, irreversible, or out of scope: stop and show the user the exact prompt text.
3. `herdr agent send-keys <pane_id> <key...>` -- only `enter`/`return`/`up`/`down`/`esc`/`escape`
   work; everything else is rejected. Need more than that? Use `agent prompt` instead.
   Then `herdr agent wait <pane_id> --until idle --until done --until blocked --timeout <ms>`.
4. Treat `unknown` like `blocked`: read and decide, don't assume success.

Repeat until `done`, or escalate to the user.

## 5. Collect results and tear down

- `herdr agent read <pane_id> --source recent-unwrapped --lines <n>` for the final output. If it's
  incomplete or raises something to follow up on, send another `agent prompt` instead of tearing down.
- Only once you're actually done: close what you opened -- `herdr tab close <tab_id>` (tab.create) or
  `herdr workspace close <workspace_id>` (workspace.create). No `pane close`.
- If you created a worktree checkout for this agent, closing the pane does not remove it. Make sure
  its work is committed and pushed (or otherwise captured), then run `git worktree remove
  <target-dir>` yourself -- removal deletes the checkout, not just the branch, so anything
  uncommitted or unpushed there is lost.
