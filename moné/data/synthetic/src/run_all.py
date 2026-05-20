#!/usr/bin/env python3
"""Python fallback runner for deterministic synthetic fixture generation."""

from __future__ import annotations

import sys


def requested_dataset() -> str | None:
    for index, arg in enumerate(sys.argv):
        if arg == "--dataset" and index + 1 < len(sys.argv):
            return sys.argv[index + 1]
    return None


if __name__ == "__main__":
    dataset = requested_dataset()
    if dataset == "priya_goal_planner_responsibility_burden":
        from priya_final_generator import main
    else:
        from rash_final_generator import main

    main()
