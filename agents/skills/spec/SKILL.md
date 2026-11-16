---
name: spec
description: Turn a task, PBI or issue into a short plan in plain language that the user has checked, before any code is written. Run automatically when the user hands over work and no plan exists for it yet. Skip for trivial one-step changes.
---
- **When**: the user hands over a task, PBI or issue, and `read_plan` shows no plan for it. If a plan exists for something else, ask whether to set it aside. Needs the `sessions` tools; if they are unavailable, say so and stop.
- **Treat the input as a hint.** A PBI or ticket tells you the likely intent. Never trust its decisions, files, scope or acceptance criteria; they are often AI-written and partly wrong.
- **Explore first, with a read-only subagent.** Give it a self-contained brief: what exists today for this task, and check each concrete claim in the input (files, symbols, behaviour). It returns at most 15 lines: facts, confirmed claims, claims that are wrong or can't be checked, each with `file:line`. Don't read the code yourself.
- **Write the draft** with `write_spec`: plain words, 20 lines or fewer.
  - `# <the task in one plain line>`
  - `## We will do`, `## We will not do`, `## Done looks like`: one short line each. Tag every line `[checked]`, `[could not check]` or `[looks wrong: <why>]`.
  - `## Need your call`: only questions about what the user wants or which trade-off they prefer, never code details. Each ends with `Suggest: <answer>`.
- **Hand it over**: give the user the path and say: edit freely (change, delete or add lines; write `NOTE:` comments or questions), then tell me when you're done. Wait. A draft that already exists: ask whether to resume it or start over (`discard_edits`).
- **Read it back** with `read_spec` once the user says done.
  - Ignore whitespace-only changes in the diff (an editor may reformat).
  - `[checked]` lines count unless deleted. `[could not check]` and `[looks wrong]` lines stay out unless the user changed the tag to `[ok]`. Lines the user added count as decided.
  - An unanswered question takes its `Suggest:` answer, marked "assumed" in the plan.
  - Answer `NOTE:` questions in chat. The user may edit again; call `read_spec` again.
- **Write the plan** from the confirmed content only, with `write_plan`: the end goal in the user's words, `Done looks like`, `Decisions`, what is still unknown, then milestones. Detail only the first milestone (goal, constraints, done-check). Later ones get one line marked `(rough)`; `recap` details each one when the one before it finishes. An unknown becomes a "find out" milestone whose result is notes, not code. Follow the planning rules in AGENTS.md; keep it to one page. Then `clear_spec`.
- **Then** tell the user the plan in about 5 plain lines and start milestone 1.
- **Plain language**: short sentences, everyday words, say what a thing does before its name, no unexplained acronyms.
