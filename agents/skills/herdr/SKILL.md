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

Pick a short name for this agent instance (aim for under 20-30 characters; the hard cap is 100) and
pass it as `--label "<name>"` so the user can tell tabs apart at a glance. Reuse this exact value as
`<name>` in step 3, so one name identifies the agent everywhere.

If `$HERDR_WORKSPACE_ID` is set, create a tab in it (shows up next to you):

```
herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd <target-dir> --label "<name>"
```

Otherwise, create a workspace:

```
herdr workspace create --cwd <target-dir> --label "<name>"
```

`<target-dir>` must be under a root you're already scoped to.

Take the pane id (`root_pane.pane_id`) and the tab/workspace id (for step 5's teardown) from the
output.

## 3. Start the agent and hand it a task

```
herdr agent start <name> --kind <your-own-kind> --pane <pane_id> [-- <agent-cli-args>]
herdr agent prompt <pane_id> "<task>" --wait --timeout <ms>
```

- `<name>` -- the same name you chose as `--label` in step 2, for herdr's own registration.
- `--kind` -- must be your own agent kind; anything else is rejected.
- `--pane <pane_id>` -- the pane id from step 2.
- `[-- <agent-cli-args>]` -- extra CLI args passed to the agent binary itself.

Target every later command by `<pane_id>`, never `<name>`. The prompt must be plain text, no
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

- `herdr agent read <pane_id> --source recent-unwrapped --lines <n>` for the final output.
- Close what you opened: `herdr tab close <tab_id>` (tab.create) or
  `herdr workspace close <workspace_id>` (workspace.create). No `pane close`.
