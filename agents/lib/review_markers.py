"""Shared REVIEW: marker detection for the pr-review and human-review scripts.

A marker is a comment line starting with REVIEW: that the working tree added, directly below the line it
comments on.
"""

import re
import subprocess
import sys

MARKER = re.compile(r"^\s*(?:#|//|--\[\[|--|;|\"|%|/\*|<!--|\*)?\s*REVIEW:\s*(.*?)\s*(?:-->|\*/|(?:--)?\]\])?\s*$")
HUNK = re.compile(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@")


def git(*args):
    command = ["git", "-c", "core.quotePath=false", *args]
    return subprocess.run(command, capture_output=True, text=True, check=True).stdout


def read_lines(path):
    try:
        with open(path, encoding="utf-8", newline="") as handle:
            return handle.read().split("\n")
    except FileNotFoundError:
        return None
    except UnicodeDecodeError:
        print(f"{path}: not UTF-8, skipped", file=sys.stderr)
        return None


def find_markers(path, lines, *diff_args):
    """Map row number to the marker match, for marker lines the working tree added in `git diff <diff_args>`."""
    added = set()
    for line in git("diff", "-U0", "--no-color", "--no-ext-diff", *diff_args, "--", path).splitlines():
        hunk = HUNK.match(line)
        if hunk:
            start = int(hunk.group(1))
            added.update(range(start, start + int(hunk.group(2) or 1)))
    matches = ((row, MARKER.match(text)) for row, text in enumerate(lines, start=1) if row in added)
    return {row: match for row, match in matches if match}


def remove_rows(path, lines, rows):
    text = "\n".join(line for row, line in enumerate(lines, start=1) if row not in rows)
    if len(lines) in rows:
        text += "\n"
    with open(path, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)
