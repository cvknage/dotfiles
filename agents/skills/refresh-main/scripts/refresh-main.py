#!/usr/bin/env python3
"""Refresh a bare-repo container's default-branch worktree and its code-graph index.

Without --once it repeats every INTERVAL seconds (default 900) and keeps the latest report in
refresh-main.status inside the git directory. A lock held for the loop's whole life allows one loop per
repository, across sandboxes and even after a kill.
"""

import argparse
import fcntl
import os
import re
import subprocess
import sys
import time

ANSI = re.compile(r"\x1b\[[0-9;]*m")


def run(*command, cwd=None, timeout=None):
    try:
        result = subprocess.run(
            command, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=timeout
        )
    except subprocess.TimeoutExpired:
        return 124, f"timed out after {timeout}s"
    return result.returncode, ANSI.sub("", result.stdout).strip()


def pick_line(command, cwd, index, timeout=None):
    code, output = run(*command, cwd=cwd, timeout=timeout)
    lines = output.splitlines()
    return code, lines[index] if lines else ""


def worktree_of(branch):
    path = None
    for line in run("git", "worktree", "list", "--porcelain")[1].splitlines():
        if line.startswith("worktree "):
            path = line[len("worktree "):]
        elif line == f"branch refs/heads/{branch}":
            return path
    return None


def server_holds(lock_path):
    if not os.path.exists(lock_path):
        return False
    with open(lock_path) as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return True
    return False


def refresh():
    code, default = run("git", "symbolic-ref", "--short", "HEAD")
    if code != 0:
        return "the repository's HEAD is detached, no default branch"
    worktree = worktree_of(default)
    if not worktree:
        return f"no worktree has {default} checked out"
    if not os.path.isdir(worktree):
        return f"{worktree} is missing, run git worktree prune"

    code, output = run("git", "fetch", "--all", "--prune", "--quiet", timeout=300)
    if code != 0:
        return f"fetch failed, nothing refreshed: {output.splitlines()[0] if output else code}"

    before = run("git", "rev-parse", "--short", "HEAD", cwd=worktree)[1]
    if run("git", "status", "--porcelain", cwd=worktree)[1]:
        update = f"{default} skipped, uncommitted changes (at {before})"
    elif run("git", "merge", "--ff-only", "--quiet", f"origin/{default}", cwd=worktree)[0] != 0:
        update = f"{default} skipped, cannot fast-forward (at {before})"
    else:
        after = run("git", "rev-parse", "--short", "HEAD", cwd=worktree)[1]
        update = f"{default} unchanged at {after}" if before == after else f"{default} {before} -> {after}"

    if server_holds(os.path.join(worktree, ".code-graph", "index.lock")):
        index = "index skipped, a server holds it"
    else:
        try:
            code, line = pick_line(["code-graph-mcp", "incremental-index"], worktree, -1, timeout=3600)
            index = line if code == 0 else f"index failed: {line}"
        except FileNotFoundError:
            index = "index failed: code-graph-mcp not found"

    try:
        health = pick_line(["code-graph-mcp", "health-check"], worktree, 0, timeout=60)[1]
    except FileNotFoundError:
        health = "health-check unavailable"
    return f"{update}; {index}; {health}"


def loop(interval):
    git_dir = run("git", "rev-parse", "--absolute-git-dir")[1]
    status_file = os.path.join(git_dir, "refresh-main.status")
    lock = open(os.path.join(git_dir, "refresh-main.lock"), "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        print(f"refresh-main: already running, status in {status_file}")
        return

    try:
        os.setsid()
    except OSError:
        pass

    def write_status(text):
        with open(status_file, "w") as handle:
            handle.write(f"{time.strftime('%F %T')} {text}\n")

    while True:
        write_status("pass running")
        try:
            report = refresh()
        except Exception as error:
            report = f"pass failed: {error}"
        write_status(report)
        time.sleep(interval)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("interval", nargs="?", type=int, default=900, help="seconds between passes")
    parser.add_argument("--once", action="store_true", help="run one pass in the foreground and print its report")
    args = parser.parse_args()
    os.environ["GIT_TERMINAL_PROMPT"] = "0"

    if run("git", "rev-parse", "--is-bare-repository")[1] != "true":
        sys.exit("refresh-main: not in a bare repository")

    if args.once:
        print(refresh())
    else:
        loop(args.interval)


main()
