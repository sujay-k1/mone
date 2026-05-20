#!/usr/bin/env python3
"""Python fallback validator for deterministic synthetic fixture generation."""

import sys


def main() -> None:
    dataset = None
    for i, arg in enumerate(sys.argv):
        if arg == "--dataset" and i + 1 < len(sys.argv):
            dataset = sys.argv[i + 1]
    if dataset == "priya_goal_planner_responsibility_burden":
        from priya_final_generator import validate_output
    elif dataset == "aarav_spend_control_rash_decisions":
        from rash_final_generator import validate_output
    else:
        raise SystemExit(f"Unsupported dataset: {dataset}")
    report = validate_output(return_report=False)
    raise SystemExit(0 if report["status"] == "pass" else 1)


if __name__ == "__main__":
    main()
