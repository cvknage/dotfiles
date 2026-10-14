#!/usr/bin/env python3
"""List the REVIEW: comments the user left in the staged files, as `path:line: text` plus the code line
each one comments on.

Markers (see review_markers.py) are those added on top of the index; REVIEW: text already in the staged
content is ignored. --remove deletes the marker lines from the working tree.
"""

import argparse
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "lib"))
import review_markers as markers


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--remove", action="store_true", help="delete the marker lines from the working tree")
    args = parser.parse_args()

    os.chdir(markers.git("rev-parse", "--show-toplevel").strip())
    for path in markers.git("diff", "--staged", "--name-only").splitlines():
        lines = markers.read_lines(path)
        if lines is None:
            continue
        found = markers.find_markers(path, lines)
        for row, match in found.items():
            above = row - 1
            while above in found:
                above -= 1
            commented = lines[above - 1].strip() if above >= 1 else "(top of file)"
            print(f"{path}:{row}: {match.group(1)}\n    on: {commented}")
        if args.remove and found:
            markers.remove_rows(path, lines, set(found))


main()
