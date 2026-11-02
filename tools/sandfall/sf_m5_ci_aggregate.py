#!/usr/bin/env python3
"""Fail closed on SF-M5 machine scopes; never turn this into human acceptance."""
import json
import os

ROUTINE = frozenset({"threaded-export", "threaded-startup", "adverse-hosts"})
FULL = frozenset({"compatibility-full", "threaded-regressions", "compatibility-science", "performance"})


def validate(results: dict, full: bool) -> dict:
    if type(full) is not bool or not isinstance(results, dict) or set(results) != ROUTINE | FULL:
        raise ValueError("Exact scope flag and complete seven-job dependency inventory are required")
    required = ROUTINE | FULL if full else ROUTINE
    failures = {}
    for name, row in results.items():
        if not isinstance(row, dict) or row.get("result") not in {"success", "skipped", "failure", "cancelled"}:
            raise ValueError("Missing or unsupported job disposition: " + name)
        expected = "success" if name in required else "skipped"
        if row["result"] != expected:
            failures[name] = {"actual": row["result"], "required": expected}
    return {"schema": "sandfall-sf-m5-machine-gates-v1", "status": "failed" if failures else "passed",
            "scope": "full" if full else "routine-threaded", "results": results, "failures": failures,
            "human_acceptance": "separate-required-gate", "release_ready": False}


def main() -> int:
    try:
        flag = os.environ["FULL"]
        if flag not in {"true", "false"}:
            raise ValueError("FULL must explicitly identify true or false")
        result = validate(json.loads(os.environ["RESULTS"]), flag == "true")
    except (ValueError, KeyError, TypeError) as exc:
        result = {"status": "failed", "error": str(exc), "release_ready": False}
    print(json.dumps(result, indent=2))
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
