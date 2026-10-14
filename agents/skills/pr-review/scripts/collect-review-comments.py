#!/usr/bin/env python3
"""Print the REVIEW: comments in a PR checkout as the `comments` array for the GitHub reviews API.

Markers (see review_markers.py) are those added on top of HEAD; REVIEW: lines already committed in the
PR are ignored. Each marker above one shifts the file down by one, so the i-th marker (1-indexed) at raw
line L targets line L - i.
"""

import argparse
import json
import os
import subprocess
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "lib"))
import review_markers as markers


def changed_files(base):
    try:
        return markers.git("diff", "--name-only", f"origin/{base}...HEAD").splitlines()
    except subprocess.CalledProcessError as error:
        sys.exit(f"cannot diff against origin/{base}: {error.stderr.strip()}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("base", help="the PR's base branch name")
    parser.add_argument("--remove", action="store_true", help="delete the marker lines from the working tree")
    args = parser.parse_args()

    os.chdir(markers.git("rev-parse", "--show-toplevel").strip())
    comments = []
    for path in changed_files(args.base):
        lines = markers.read_lines(path)
        if lines is None:
            continue
        found = markers.find_markers(path, lines, "HEAD")
        for shift, (row, match) in enumerate(sorted(found.items()), start=1):
            target = row - shift
            if target < 1:
                print(f"{path}:{row}: marker has no line above it, skipped", file=sys.stderr)
                continue
            comments.append({"path": path, "line": target, "side": "RIGHT", "body": match.group(1)})
        if args.remove and found:
            markers.remove_rows(path, lines, set(found))

    json.dump(comments, sys.stdout, indent=2)
    print()


main()
