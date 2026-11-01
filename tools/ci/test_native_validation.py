#!/usr/bin/env python3
"""Contract checks for the Native workflow inventory and fail-closed join."""

from __future__ import annotations

import json
from pathlib import Path
import re
import unittest

from native_aggregate import aggregate


ROOT = Path(__file__).resolve().parents[2]


def job_block(workflow: str, job_id: str) -> str:
    markers = list(re.finditer(r"(?m)^  ([A-Za-z0-9_-]+):\s*$", workflow))
    for index, marker in enumerate(markers):
        if marker.group(1) != job_id:
            continue
        end = markers[index + 1].start() if index + 1 < len(markers) else len(workflow)
        return workflow[marker.start() : end]
    raise AssertionError(f"workflow is missing job {job_id!r}")


class NativeWorkflowContractTests(unittest.TestCase):
    def setUp(self):
        self.workflow_path = ROOT / ".github/workflows/native.yml"
        self.workflow = self.workflow_path.read_text(encoding="utf-8")
        self.inventory = json.loads(
            (ROOT / "tools/ci/native_validation_inventory.json").read_text(
                encoding="utf-8"
            )
        )

    def test_inventory_checks_appear_in_their_assigned_jobs(self):
        self.assertEqual(self.inventory["workflow"], ".github/workflows/native.yml")
        for item in self.inventory["checks"]:
            with self.subTest(job=item["job"], marker=item["marker"]):
                self.assertIn(item["marker"], job_block(self.workflow, item["job"]))

    def test_stable_check_waits_for_every_suite(self):
        aggregate_job = job_block(self.workflow, self.inventory["stable_check_job"])
        for suite in self.inventory["suite_jobs"]:
            with self.subTest(suite=suite):
                self.assertIn(f"- {suite}", aggregate_job)
        self.assertIn("always()", aggregate_job)
        self.assertIn("native_aggregate.py", aggregate_job)

    def test_soliding_sanitizer_target_keeps_all_eight_test_programs(self):
        makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
        lines = makefile.splitlines()
        for target_name, dependencies in self.inventory["make_target_dependencies"].items():
            target_line = next(
                line for line in lines if line.startswith(f"{target_name}:")
            )
            for dependency in dependencies:
                with self.subTest(target=target_name, dependency=dependency):
                    self.assertIn(dependency, target_line)

    def test_full_native_source_and_make_recipe_inventories_remain_covered(self):
        makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
        test_sources = next(
            line for line in makefile.splitlines() if line.startswith("TEST_SOURCES :=")
        )
        for source in self.inventory["native_test_sources"]:
            with self.subTest(source=source):
                self.assertIn(source, test_sources)
        for target_name, markers in self.inventory["make_recipe_markers"].items():
            start = makefile.index(f"{target_name}:")
            following_target = makefile.find("\n\n", start)
            recipe = makefile[start:] if following_target < 0 else makefile[start:following_target]
            for marker in markers:
                with self.subTest(target=target_name, marker=marker):
                    self.assertIn(marker, recipe)


class NativeAggregateTests(unittest.TestCase):
    def env(self, **overrides):
        result = {
            "EVENT_NAME": "workflow_dispatch",
            "EVENT_ACTION": "",
            "READY_SCOPE_RESULT": "skipped",
            "READY_SCOPE_REQUIRED": "",
            "CORE_RESULT": "success",
            "THREAD_SAFETY_RESULT": "success",
            "GENERAL_SANITIZERS_RESULT": "success",
            "SPECIALIZED_SANITIZERS_RESULT": "success",
        }
        result.update(overrides)
        return result

    def test_dispatch_passes_with_all_suites_successful(self):
        code, report = aggregate(self.env())
        self.assertEqual(code, 0)
        self.assertIn("All required Native suites succeeded", report)

    def test_failure_cancellation_and_skip_fail_closed(self):
        for status in ("failure", "cancelled", "skipped", ""):
            with self.subTest(status=status):
                code, report = aggregate(self.env(CORE_RESULT=status))
                self.assertEqual(code, 1)
                self.assertIn("FAIL CLOSED", report)

    def test_ready_for_review_requires_successful_positive_scope(self):
        valid = self.env(
            EVENT_NAME="pull_request",
            EVENT_ACTION="ready_for_review",
            READY_SCOPE_RESULT="success",
            READY_SCOPE_REQUIRED="true",
        )
        self.assertEqual(aggregate(valid)[0], 0)
        for result, required in (("failure", "true"), ("success", "false"), ("", "")):
            with self.subTest(result=result, required=required):
                code, report = aggregate(
                    self.env(
                        EVENT_NAME="pull_request",
                        EVENT_ACTION="ready_for_review",
                        READY_SCOPE_RESULT=result,
                        READY_SCOPE_REQUIRED=required,
                    )
                )
                self.assertEqual(code, 1)
                self.assertIn("ready-for-review", report)

    def test_unexpected_event_fails_closed(self):
        code, report = aggregate(self.env(EVENT_NAME="schedule"))
        self.assertEqual(code, 1)
        self.assertIn("unexpected event name", report)


if __name__ == "__main__":
    unittest.main()
