"""Plain-code file I/O for .agent-sessions/.

The file operation itself needs no LLM turn.
"""

import difflib
import shutil
from datetime import date
from pathlib import Path

from mcp.server.mcpserver import MCPServer

mcp = MCPServer("agent-sessions")


def _sessions_dir(repo_root: str) -> Path:
    return Path(repo_root) / ".agent-sessions"


def _ensure_sessions_dir(repo_root: str) -> Path:
    sessions_dir = _sessions_dir(repo_root)
    sessions_dir.mkdir(parents=True, exist_ok=True)
    return sessions_dir


@mcp.tool()
def read_plan(repo_root: str) -> str:
    """Return the current session plan, or a notice if none exists.

    Args:
        repo_root: Absolute path to the repository root.
    """
    path = _sessions_dir(repo_root) / "plan.md"
    if not path.exists():
        return "No session plan recorded."
    return path.read_text(encoding="utf-8")


@mcp.tool()
def read_notes(repo_root: str) -> str:
    """Return the session log, or a notice if none exists.

    Args:
        repo_root: Absolute path to the repository root.
    """
    path = _sessions_dir(repo_root) / "notes.md"
    if not path.exists():
        return "No session log recorded."
    return path.read_text(encoding="utf-8")


@mcp.tool()
def append_note(repo_root: str, bullets: list[str]) -> str:
    """Batch-append findings to .agent-sessions/notes.md under today's date.

    Call once per exploration sweep or milestone, not per observation --
    combine every pending finding into a single call. Reserve for high-value
    captures a later session would need: dead ends, non-obvious map
    knowledge, decisions. Routine observations don't merit a call.

    Args:
        repo_root: Absolute path to the repository root.
        bullets: Terse findings to append, one per line, ideally with
            file:line references. No prose, no code dumps.

    Raises:
        ValueError: If bullets is empty.
    """
    if not bullets:
        raise ValueError("bullets must be non-empty")

    sessions_dir = _ensure_sessions_dir(repo_root)
    notes_path = sessions_dir / "notes.md"

    try:
        existing = notes_path.read_text(encoding="utf-8")
    except FileNotFoundError:
        existing = ""

    header = f"## {date.today().isoformat()}"
    reversed_lines = reversed(existing.splitlines())
    last_section = next(
        (ln for ln in reversed_lines if ln.startswith("## ")), None
    )
    has_header = last_section == header
    has_content = bool(existing.strip())
    terminator = "" if not existing or existing.endswith("\n") else "\n"

    with notes_path.open("a", encoding="utf-8") as notes_file:
        notes_file.write(terminator)
        if not has_header:
            separator = "\n" if has_content else ""
            notes_file.write(f"{separator}{header}\n")
        for bullet in bullets:
            notes_file.write(f"- {bullet}\n")

    return f"Appended {len(bullets)} note(s) to {notes_path}"


def _with_newline(content: str) -> str:
    if not content.strip():
        raise ValueError("content must be non-empty")
    return content if content.endswith("\n") else content + "\n"


def _write_plan_file(repo_root: str, content: str) -> Path:
    text = _with_newline(content)
    sessions_dir = _ensure_sessions_dir(repo_root)
    plan_path = sessions_dir / "plan.md"
    plan_path.write_text(text, encoding="utf-8")
    return plan_path


@mcp.tool()
def write_plan(repo_root: str, content: str) -> str:
    """Start a new task: replace plan.md and archive any prior notes.

    Call with the finished plan already composed -- small, independently
    verifiable milestones, each with a concrete done-check. Size each
    milestone to finish in one fresh agent session, and state any decisions
    or constraints that bind it, so an agent seeing only that milestone can
    execute it. Name files or an approach only where already known. This
    tool only persists the plan; breaking the task into milestones is the
    caller's job.

    Use this only when starting genuinely new work; never call it just to
    revise the plan for the task already in progress -- use revise_plan
    for that, since it leaves notes.md untouched. Notes from the finished
    task are moved to notes.md.bak (overwriting any earlier backup), not
    deleted outright.

    Args:
        repo_root: Absolute path to the repository root.
        content: The full plan.md content to write, replacing any existing
            plan.

    Raises:
        ValueError: If content is empty or whitespace-only.
    """
    plan_path = _write_plan_file(repo_root, content)

    notes_path = plan_path.parent / "notes.md"
    notes_status = "no prior notes"
    if notes_path.exists():
        backup_path = plan_path.parent / "notes.md.bak"
        try:
            notes_path.replace(backup_path)
            notes_status = f"archived prior notes to {backup_path.name}"
        except OSError as exc:
            notes_status = f"could not archive prior notes: {exc}"

    return f"Wrote {plan_path}; {notes_status}"


@mcp.tool()
def revise_plan(repo_root: str, content: str) -> str:
    """Replace plan.md with a revised plan for the task already in progress.

    Use this to update milestones as the current task's plan evolves; keep
    each one self-contained (goal, constraints, done-check) as in write_plan.
    Unlike write_plan, this does not touch notes.md -- notes accumulated
    so far stay intact. Use write_plan instead when starting new,
    unrelated work.

    Args:
        repo_root: Absolute path to the repository root.
        content: The full plan.md content to write, replacing any existing
            plan.

    Raises:
        ValueError: If content is empty or whitespace-only.
    """
    plan_path = _write_plan_file(repo_root, content)
    return f"Updated {plan_path}"


def _spec_paths(repo_root: str) -> tuple[Path, Path]:
    sessions_dir = _sessions_dir(repo_root)
    return sessions_dir / "spec.md", sessions_dir / "spec.md.orig"


@mcp.tool()
def write_spec(
    repo_root: str, content: str, discard_edits: bool = False
) -> str:
    """Write a spec draft for the user to edit, plus an untouched copy.

    The copy is what read_spec diffs the user's edits against. Refuses
    when a draft exists that differs from its copy (or has no copy)
    unless discard_edits is true. Returns the path to hand the user.

    Args:
        repo_root: Absolute path to the repository root.
        content: The full draft text.
        discard_edits: Overwrite an existing draft, edited or not.

    Raises:
        ValueError: If content is empty, or the existing draft may hold
            user edits.
    """
    text = _with_newline(content)

    spec_path, orig_path = _spec_paths(repo_root)
    if not discard_edits and spec_path.exists():
        unchanged = orig_path.exists() and spec_path.read_text(
            encoding="utf-8"
        ) == orig_path.read_text(encoding="utf-8")
        if not unchanged:
            raise ValueError(
                "spec.md may hold user edits; read them with read_spec, "
                "then pass discard_edits=true to overwrite"
            )

    _ensure_sessions_dir(repo_root)
    orig_path.write_text(text, encoding="utf-8")
    spec_path.write_text(text, encoding="utf-8")
    return f"Wrote {spec_path}"


@mcp.tool()
def read_spec(repo_root: str) -> str:
    """Return the user's edits to the spec draft, then its full current text.

    The edits are a unified diff of spec.md.orig against spec.md, so
    deleted lines show in the diff and added lines in the current text.

    Args:
        repo_root: Absolute path to the repository root.
    """
    spec_path, orig_path = _spec_paths(repo_root)
    if not spec_path.exists():
        return "No spec draft."

    current = spec_path.read_text(encoding="utf-8")
    if not orig_path.exists():
        changes = "Unknown: spec.md.orig is missing."
        return f"## Changes\n{changes}\n\n## Current\n{current}"
    original = orig_path.read_text(encoding="utf-8")
    diff = "".join(
        difflib.unified_diff(
            original.splitlines(keepends=True),
            current.splitlines(keepends=True),
            "spec.md.orig",
            "spec.md",
        )
    )
    return f"## Changes\n{diff or 'No changes.'}\n\n## Current\n{current}"


@mcp.tool()
def clear_spec(repo_root: str) -> str:
    """Delete the spec draft and its untouched copy.

    Args:
        repo_root: Absolute path to the repository root.
    """
    spec_path, orig_path = _spec_paths(repo_root)
    removed = [p.name for p in (spec_path, orig_path) if p.exists()]
    for path in (spec_path, orig_path):
        path.unlink(missing_ok=True)
    if not removed:
        return "No spec draft to remove."
    return f"Removed {', '.join(removed)}"


@mcp.tool()
def reset_session(repo_root: str) -> str:
    """Delete the entire .agent-sessions/ directory and everything in it.

    Purely mechanical -- no content to compose. Durable knowledge should
    already be in the memory graph before calling this; session state itself
    is not preserved.

    Args:
        repo_root: Absolute path to the repository root.
    """
    sessions_dir = _sessions_dir(repo_root)
    if sessions_dir.exists():
        shutil.rmtree(sessions_dir)
        return f"Removed {sessions_dir}"
    return f"Nothing to remove at {sessions_dir}"


if __name__ == "__main__":
    mcp.run()
