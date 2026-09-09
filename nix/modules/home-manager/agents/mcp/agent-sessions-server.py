"""Plain-code file I/O for .agent-sessions/.

The file operation itself needs no LLM turn.
"""

import shutil
from datetime import date
from pathlib import Path

from mcp.server.fastmcp import FastMCP

mcp = FastMCP("agent-sessions")


@mcp.tool()
def read_plan(repo_root: str) -> str:
    """Return the current session plan, or a notice if none exists.

    Args:
        repo_root: Absolute path to the repository root.
    """
    path = Path(repo_root) / ".agent-sessions" / "plan.md"
    if not path.exists():
        return "No session plan recorded."
    return path.read_text(encoding="utf-8")


@mcp.tool()
def read_notes(repo_root: str) -> str:
    """Return the session log, or a notice if none exists.

    Args:
        repo_root: Absolute path to the repository root.
    """
    path = Path(repo_root) / ".agent-sessions" / "notes.md"
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
    """
    if not bullets:
        raise ValueError("bullets must be non-empty")

    sessions_dir = Path(repo_root) / ".agent-sessions"
    sessions_dir.mkdir(parents=True, exist_ok=True)
    notes_path = sessions_dir / "notes.md"

    header = f"## {date.today().isoformat()}"
    has_header = False
    if notes_path.exists():
        with notes_path.open("r", encoding="utf-8") as existing:
            has_header = any(line.rstrip("\n") == header for line in existing)

    with notes_path.open("a", encoding="utf-8") as notes_file:
        if not has_header:
            notes_file.write(f"\n{header}\n")
        for bullet in bullets:
            notes_file.write(f"- {bullet}\n")

    return f"Appended {len(bullets)} note(s) to {notes_path}"


@mcp.tool()
def write_plan(repo_root: str, content: str) -> str:
    """Replace .agent-sessions/plan.md with the given content.

    Call with the finished plan already composed -- small, independently
    verifiable milestones, each with a concrete done-check. This tool only
    persists it; breaking the task into milestones is the caller's job.

    Args:
        repo_root: Absolute path to the repository root.
        content: The full plan.md content to write, replacing any existing
            plan.
    """
    if not content.strip():
        raise ValueError("content must be non-empty")

    sessions_dir = Path(repo_root) / ".agent-sessions"
    sessions_dir.mkdir(parents=True, exist_ok=True)
    plan_path = sessions_dir / "plan.md"
    plan_path.write_text(
        content if content.endswith("\n") else content + "\n", encoding="utf-8"
    )

    return f"Wrote {plan_path}"


@mcp.tool()
def reset_session(repo_root: str) -> str:
    """Delete the entire .agent-sessions/ directory and everything in it.

    Purely mechanical -- no content to compose. Durable knowledge should
    already be in the memory graph before calling this; session state itself
    is not preserved.

    Args:
        repo_root: Absolute path to the repository root.
    """
    sessions_dir = Path(repo_root) / ".agent-sessions"
    if sessions_dir.exists():
        shutil.rmtree(sessions_dir)
        return f"Removed {sessions_dir}"
    return f"Nothing to remove at {sessions_dir}"


if __name__ == "__main__":
    mcp.run()
