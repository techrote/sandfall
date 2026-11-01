#!/usr/bin/env python3
"""Fail closed unless every required Native validation suite succeeded."""

from __future__ import annotations

import os


RESULT_KEYS = {
    "native-core": "CORE_RESULT",
    "native-thread-safety": "THREAD_SAFETY_RESULT",
    "native-general-sanitizers": "GENERAL_SANITIZERS_RESULT",
    "native-specialized-sanitizers": "SPECIALIZED_SANITIZERS_RESULT",
}


def aggregate(env: dict[str, str]) -> tuple[int, str]:
    errors: list[str] = []
    event_name = env.get("EVENT_NAME", "")
    event_action = env.get("EVENT_ACTION", "")

    if event_name not in {"push", "pull_request", "workflow_dispatch"}:
        errors.append(f"unexpected event name: {event_name or '<missing>'}")

    if event_name == "pull_request" and event_action == "ready_for_review":
        scope_result = env.get("READY_SCOPE_RESULT", "")
        scope_required = env.get("READY_SCOPE_REQUIRED", "")
        if scope_result != "success":
            errors.append(
                "ready-for-review scope classifier did not succeed "
                f"(result={scope_result or '<missing>'})"
            )
        if scope_required != "true":
            errors.append(
                "ready-for-review scope did not require Native validation "
                f"(required={scope_required or '<missing>'})"
            )

    results: list[str] = []
    for job, key in RESULT_KEYS.items():
        result = env.get(key, "")
        results.append(f"{job}={result or '<missing>'}")
        if result != "success":
            errors.append(f"{job} must succeed; observed {result or '<missing>'}")

    report = "Native suite results: " + ", ".join(results)
    if event_name == "pull_request" and event_action == "ready_for_review":
        report += (
            "; scope classifier="
            + (env.get("READY_SCOPE_RESULT") or "<missing>")
            + ", required="
            + (env.get("READY_SCOPE_REQUIRED") or "<missing>")
        )
    if errors:
        return 1, report + "\nFAIL CLOSED: " + "; ".join(errors)
    return 0, report + "\nAll required Native suites succeeded."


def main() -> int:
    code, report = aggregate(dict(os.environ))
    print(report)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
