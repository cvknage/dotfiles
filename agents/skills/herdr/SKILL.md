---
name: herdr
description: Launch another coding-agent instance in its own `herdr` pane, hand it a self-contained task, and supervise it to completion -- including noticing when it's blocked on a permission/approval prompt and deciding whether to respond. Use when a task should run as a separate, possibly long-running or prompt-heavy agent instance instead of blocking the current session. Generic orchestration only; the target task comes from whatever skill or instructions you put in the prompt you hand the spawned agent.
---

Drives `herdr` (https://herdr.dev) to run a second agent instance hands-off. Pure orchestration -- the
task itself comes from the prompt you send in step 4.

Commands go through a local proxy, not the real herdr socket. It accepts fewer things than the plain
`herdr` CLI docs describe (`herdr worktree open` and `worktree list` are rejected, for example), so
follow the exact forms below, not `--help` output.

## 1. Preconditions

- `command -v herdr` -- if missing, tell the user.
- `[ -n "$HERDR_SOCKET_PATH" ]` -- if unset, tell the user herdr isn't available this session.
  Don't run `herdr status server` to check instead; it will not give a useful answer here.

## 2. Give the agent a checkout

If the agent can share your current directory, use it as `<target-dir>` and skip to step 3.

For its own branch and checkout, create the worktree yourself with plain git, with `<target-dir>` under
a root you're already scoped to and can write to:

```
git worktree add -b <branch-name> <target-dir> [<base-ref>]
```

Then prepare it before the agent starts:

- **Code-graph index.** Run this skill's `scripts/seed-code-graph.sh <base-ref> <target-dir>` from any
  worktree of the repo, so the agent skips the cold index build. `<base-ref>` is the ref you gave
  `git worktree add`, or the branch you ran it from when you gave none. The script backs up the index of the worktree that
  has that branch checked out, and does nothing when there is none or it has no index. Use it instead of
  copying the files (which can tear while a server is running) or `code-graph-mcp snapshot create` (which
  drops the embeddings). The agent's server catches up on whatever changed since the base was last
  indexed. To confirm, run `code-graph-mcp health-check` in `<target-dir>` from your own shell (it isn't
  a herdr command), or have the agent run it.
- **Dev shell.** A fresh worktree has no active dev shell. If it has a flake dev shell, tell the agent in
  step 4's prompt to run its commands through `nix develop`.

## 3. Place the agent in herdr

Pick two names, every time, and never conflate them:

- An **assignment name**, once up front for each group of related agents. It is always the label of the
  tab that holds the group, from that tab's very first creation call -- never an individual agent's name,
  even when there's only one agent.
- An **agent name** per spawned agent (aim for under 20-30 characters; the hard cap is 100). It is the
  `agent start` name in step 4 and its own pane's label -- never a tab or workspace label.

**Layout:** each worktree gets its own workspace, labelled with the worktree's name. Inside a workspace,
agents working on closely related tasks share one tab, one pane each. Unrelated tasks, such as different
services, get separate tabs. When there is no separate worktree, label the workspace with the assignment
name instead.

Create the first pane in one of three ways:

- **A worktree you created in step 2** gets its own workspace. Its first tab takes the first
  assignment's name:

  ```
  herdr workspace create --cwd <target-dir> --label "<worktree-name>"
  herdr tab rename <tab_id> "<assignment-name>"
  ```

- **The worktree you're already in** uses your current workspace (`$HERDR_WORKSPACE_ID`), where a new
  tab shows up next to you:

  ```
  herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd <target-dir> --label "<assignment-name>"
  ```

- **No `$HERDR_WORKSPACE_ID` and no new worktree:** create a workspace labelled with the assignment name.

Take the pane id (`root_pane.pane_id`) and the tab or workspace id (for step 6's teardown) from the
output, then label the pane with the agent's own name:

```
herdr pane rename <pane_id> "<agent-name>"
```

For each additional agent on the same assignment, split a pane off any pane already in that tab (the
first agent's root pane works) and label it the same way:

```
herdr pane split <pane_id> --direction right|down
herdr pane rename <new_pane_id> "<agent-name>"
```

`<new_pane_id>` is `pane.pane_id` from the split's own output (not `root_pane.pane_id` -- that field
only appears on workspace/tab creation). Repeat step 4 for it. To rename an assignment later, use
`herdr tab rename <tab_id> "<assignment-name>"`, or `herdr workspace rename <workspace_id>
"<assignment-name>"` when the workspace is labelled with it.

## 4. Start the agent and hand it a task

```
herdr agent start <agent-name> --kind <your-own-kind> --pane <pane_id> [-- <agent-cli-args>]
herdr agent prompt <pane_id> "<task>" --wait --until working --until blocked --timeout 10000
```

- `<agent-name>` -- this agent's own name from step 3 (the same one used for `pane rename`, not the
  assignment name), for herdr's own registration.
- `--kind` -- must be your own agent kind; anything else is rejected.
- `--pane <pane_id>` -- the pane id from step 3.
- `[-- <agent-cli-args>]` -- extra CLI args passed to the agent binary itself.

Target every later command by `<pane_id>`, never `<agent-name>`. The prompt must be plain text, no
control bytes or ANSI escapes. The spawned agent has zero context: brief it like a fresh subagent,
including what "done" looks like.

The `prompt` call only confirms the agent picked the task up: `--wait --until working` returns once it
starts working (`agent_prompt_stalled` means it never did). Waiting for the work itself is step 5, so
this call does not hold your turn for the whole task.

## 5. Supervise it

Wait with the command below, without `--timeout`. Run it as a background command if you can, so you're
notified when it exits instead of blocking:

```
herdr agent wait <pane_id> --until idle --until done --until blocked --until unknown
```

It returns when the agent reaches one of those states; `unknown` is not in herdr's default set, so it
is listed here. A foreground wait with a timeout only fails at the timeout and tells you nothing. If the
task has run far longer than it should, read the pane (below) instead of waiting on.

`blocked` means herdr detected an approval/question UI -- not that the request is safe to approve.

1. `herdr agent read <pane_id> --source recent` before anything else.
2. Approve only read-only/idempotent actions inside the task's stated scope. For anything
   destructive, irreversible, or out of scope: stop and show the user the exact prompt text.
3. `herdr agent send-keys <pane_id> <key...>` -- only `enter`/`return`/`up`/`down`/`esc`/`escape`
   work; everything else is rejected. Need more than that? Use `agent prompt` instead.
   Then wait again as above.
4. Treat `unknown` like `blocked`: read and decide, don't assume success.

Repeat until `done`, or escalate to the user.

## 6. Collect results and tear down

- `herdr agent read <pane_id> --source recent-unwrapped --lines <n>` for the final output. If it's
  incomplete or raises something to follow up on, send another `agent prompt` instead of tearing down.
- Only once you're actually done, close what you opened: `herdr tab close <tab_id>` for a tab you
  created, or `herdr workspace close <workspace_id>` for a workspace. There is no `pane close`.
- Closing herdr's workspace or tab does not remove a worktree you created in step 2. After closing it,
  make sure the worktree's work is committed and pushed (or otherwise captured), then run
  `git worktree remove <target-dir>` yourself -- removal deletes the checkout, not just the branch, so
  anything uncommitted or unpushed there is lost.
