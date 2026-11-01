#!/usr/bin/env python3
"""Static trigger, source-identity and concurrency contracts for CI workflows."""

import json
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]


def workflow(name: str) -> str:
    return (ROOT / ".github" / "workflows" / name).read_text(encoding="utf-8")


def job_block(text: str, job_id: str) -> str:
    markers = list(re.finditer(r"(?m)^  ([A-Za-z0-9_-]+):\s*$", text))
    for index, marker in enumerate(markers):
        if marker.group(1) == job_id:
            end = markers[index + 1].start() if index + 1 < len(markers) else len(text)
            return text[marker.start() : end]
    raise AssertionError(f"workflow is missing job {job_id!r}")


class CiWorkflowContractTests(unittest.TestCase):
    def test_expensive_workflows_use_exact_workflow_path_filters(self):
        native = workflow("native.yml")
        gdextension = workflow("gdextension.yml")
        for name, text in (("native.yml", native), ("gdextension.yml", gdextension)):
            with self.subTest(name=name):
                self.assertIn("paths:", text)
                self.assertNotIn(".github/workflows/**", text)
        self.assertIn(".github/workflows/native.yml", native)
        self.assertEqual(native.count("\'.github/workflows/sf-m4-web.yml\'"), 2)
        self.assertIn("changed_files", native)
        self.assertIn("Incomplete changed-file inventory", native)
        self.assertIn(".github/workflows/gdextension.yml", gdextension)
        self.assertIn("tools/ci/godot_regression_profiles.json", gdextension)
        self.assertGreaterEqual(gdextension.count("--profile sandfall-current"), 2)

    def test_ci_contract_workflow_covers_workflow_and_ci_script_changes(self):
        text = workflow("ci-validation.yml")
        self.assertIn(".github/workflows/**", text)
        self.assertIn("tools/ci/**", text)
        self.assertIn("actionlint_1.7.12_linux_amd64.tar.gz", text)
        self.assertIn("sha256sum --check --strict", text)
        self.assertIn("test_ci_provider_policy.py", text)
        self.assertIn("test_native_validation.py", text)
        self.assertIn("test_ci_workflow_contract.py", text)

    def test_mainline_web_gate_reuses_source_matched_m4_and_retains_m3(self):
        wrapper = workflow("web-acceptance.yml")
        reusable = workflow("sf-m4-web.yml")
        build_script = (ROOT / "tools/sandfall/sf_m4_ci.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn(".github/workflows/web-acceptance.yml", wrapper)
        self.assertIn(".github/workflows/sf-m4-web.yml", wrapper)
        self.assertNotIn(".github/workflows/**", wrapper)
        self.assertIn("uses: ./.github/workflows/sf-m4-web.yml", wrapper)
        self.assertIn("routine: true", wrapper)
        self.assertIn("github.event.pull_request.draft == false", wrapper)
        self.assertIn("tools/build_web.py", wrapper)
        self.assertIn("tools/sandfall/**", wrapper)
        self.assertNotIn("tools/**", wrapper)
        # Only the complete M4 branch suite replaces this routine invocation.
        # An M3 branch's dedicated workflow does not cover project-file behavior.
        self.assertNotIn("startsWith(github.head_ref, 'sf-m3/')", wrapper)
        self.assertIn("startsWith(github.head_ref, 'sf-m4/')", wrapper)
        self.assertIn("workflow_call:", reusable)
        # D01 changes production instrumentation and must retain full M4
        # qualification. Admit only that exact additional branch.
        self.assertEqual(
            re.findall(r"(?m)^    branches: (.+)$", job_block(reusable, "push")),
            ["['sf-m4/**', 'sf-m5/d01-qualification']"],
        )
        self.assertIn("if: ${{ !inputs.routine }}", reusable)
        self.assertEqual(
            reusable.count("ref: ${{ github.event.pull_request.head.sha || github.sha }}"),
            9,
        )
        self.assertNotIn("ref: ${{ github.sha }}", reusable)
        self.assertIn("for bodies in 0 1 3 8 16", reusable)
        self.assertIn("node tools/sandfall/sf_m3_browser.mjs", reusable)
        self.assertIn("sf_m1_browser, sf_m2_browser", reusable)
        self.assertIn("--profile compat", build_script)
        self.assertIn("--native-cpp", build_script)
        self.assertIn("sf_m3_reconcile.py", build_script)
        self.assertIn("sf_m2_ci.sh", build_script)

    def test_m4_targeted_preflight_precedes_the_unchanged_browser_matrix(self):
        text = workflow("sf-m4-web.yml")
        exporter = job_block(text, "web-export")
        self.assertIn("if: ${{ !inputs.routine }}", exporter)
        self.assertLess(exporter.index("sf_m4_ci.sh build"), exporter.index("sf_m1_layout_preflight.sh"))
        self.assertLess(exporter.index("sf_m1_layout_preflight.sh"), exporter.index("actions/upload-artifact@"))
        for name in ("ordinary-web", "physical-workshop", "legacy-contract",
                     "portable-projects", "exhibitions", "exhibition-portraits"):
            self.assertIn("needs: web-export", job_block(text, name))
        preflight = (ROOT / "tools/sandfall/sf_m1_layout_preflight.sh").read_text()
        self.assertIn("for trial in focused-dpr1 profiles-dpr1 profiles-dpr2; do", preflight)
        self.assertIn("sf_m4_verify_web_artifact.py", preflight)
        self.assertIn("sf_m1_browser.mjs", preflight)
        self.assertIn("set -euo pipefail", preflight)
        self.assertNotIn("continue-on-error", exporter)
        self.assertNotIn("--retry", preflight)

    def test_m4_full_and_routine_job_inventories_preserve_required_coverage(self):
        text = workflow("sf-m4-web.yml")
        jobs_text = text.split("\njobs:\n", 1)[1]
        job_ids = re.findall(r"(?m)^  ([A-Za-z0-9_-]+):\s*$", jobs_text)
        expected = {
            "full-native", "source-native", "web-export", "ordinary-web",
            "physical-workshop", "legacy-contract", "portable-projects",
            "exhibitions", "exhibition-portraits",
        }
        self.assertEqual(set(job_ids), expected)
        self.assertEqual(len(job_ids), len(expected))
        call = job_block(text, "workflow_call")
        self.assertRegex(call, r"routine:\n(?:.*\n)*?        type: boolean\n"
                              r"        required: false\n        default: false")
        self.assertIn("  workflow_dispatch:\n", text)
        blocks = {name: job_block(jobs_text, name) for name in job_ids}
        targeted_only = {"full-native", "exhibition-portraits"}
        for name, block in blocks.items():
            with self.subTest(job=name):
                conditions = re.findall(r"(?m)^    if: (.+)$", block)
                self.assertEqual(
                    conditions, ["${{ !inputs.routine }}"] if name in targeted_only else [],
                )
                self.assertNotIn("continue-on-error:", block)

        def profiles(name):
            result = re.findall(
                r"(?m)^          - \{width: (\d+), height: (\d+), dpr: (\d+)\}$",
                blocks[name],
            )
            self.assertEqual(result, [("800", "450", "1"), ("640", "400", "2")])
            self.assertIn("fail-fast: false", blocks[name])
            return len(result)

        harnesses = re.search(r"(?m)^        harness: \[([^\]]+)\]$", blocks["ordinary-web"])
        self.assertIsNotNone(harnesses)
        self.assertEqual(harnesses[1].split(", "), ["sf_m1_browser", "sf_m2_browser"])
        capacities = re.search(
            r"(?m)^        bodies: \$\{\{ fromJSON\(inputs\.routine && '([^']+)' \|\| '([^']+)'\) \}\}$",
            blocks["portable-projects"],
        )
        self.assertIsNotNone(capacities)
        routine_bodies, full_bodies = map(json.loads, capacities.groups())
        self.assertEqual(routine_bodies, [0, 16])
        self.assertEqual(full_bodies, [0, 1, 3, 8, 16])
        entries = re.search(r"(?m)^        entry: \[([^\]]+)\]$", blocks["exhibition-portraits"])
        self.assertIsNotNone(entries)
        self.assertEqual(entries[1].split(", "), [
            "gravity_cascade", "fluid_messenger", "passive_subject_ride",
            "endless_kinetic_loop", "intervention", "time_controls", "sixteen_body",
        ])
        full_counts = {
            "full-native": 1, "source-native": 1, "web-export": 1, "legacy-contract": 1,
            "ordinary-web": len(harnesses[1].split(", ")) * profiles("ordinary-web"),
            "physical-workshop": profiles("physical-workshop"),
            "portable-projects": len(full_bodies) * profiles("portable-projects"),
            "exhibitions": profiles("exhibitions"),
            "exhibition-portraits": len(entries[1].split(", ")) * profiles("exhibition-portraits"),
        }
        routine_counts = {name: count for name, count in full_counts.items() if name not in targeted_only}
        routine_counts["portable-projects"] = len(routine_bodies) * profiles("portable-projects")
        self.assertEqual(sum(full_counts.values()), 36)
        self.assertEqual(sum(routine_counts.values()), 15)

    def test_m4_every_job_checks_out_exact_source_and_browser_uses_same_run_export(self):
        text = workflow("sf-m4-web.yml").split("\njobs:\n", 1)[1]
        browser_jobs = {
            "ordinary-web", "physical-workshop", "portable-projects",
            "exhibitions", "exhibition-portraits", "legacy-contract",
        }
        for name in re.findall(r"(?m)^  ([A-Za-z0-9_-]+):\s*$", text):
            block = job_block(text, name)
            with self.subTest(job=name):
                self.assertEqual(block.count("uses: actions/checkout@"), 1)
                self.assertEqual(
                    block.count("ref: ${{ github.event.pull_request.head.sha || github.sha }}"), 1,
                )
                if name in browser_jobs:
                    self.assertIn("    needs: web-export\n", block)
                    self.assertEqual(block.count("uses: actions/download-artifact@"), 1)
                    artifact = "legacy-web" if name == "legacy-contract" else "fresh-web"
                    self.assertIn("name: sandfall-sf-m4-" + artifact, block)
                    self.assertNotIn("run-id:", block)
        self.assertIn("sf_m4_verify_web_artifact.py", job_block(text, "physical-workshop"))
        self.assertIn("sf_m4_browser_ci.sh projects", job_block(text, "portable-projects"))
        self.assertIn("sf_m4_browser_ci.sh gallery", job_block(text, "exhibitions"))
        self.assertNotIn("GALLERY_ENTRY:", job_block(text, "exhibitions"))
        self.assertIn("sf_m2_ci.sh legacy", job_block(text, "legacy-contract"))

    def test_windows_portability_requires_explicit_manual_input(self):
        text = workflow("gdextension.yml")
        self.assertIn("windows_portability:\n        description:", text)
        self.assertIn("default: false", text)
        for job_id in ("windows-build", "windows-regression"):
            with self.subTest(job=job_id):
                self.assertIn("inputs.windows_portability == true", job_block(text, job_id))
        self.assertIn("needs.windows-build.result == 'success'", job_block(text, "windows-regression"))
        self.assertIn("windows-runtime-${{ github.run_id }}", text)
        self.assertIn("--fresh-windows-runtime build/windows-runtime --profile sandfall-current", text)
        self.assertIn("linux-regression-gate:", text)

    def test_gdextension_ready_scope_covers_ci_changes_and_fails_closed(self):
        text = workflow("gdextension.yml")
        self.assertIn('ignored_prefixes = ("docs/",)', text)
        self.assertIn("Incomplete changed-file inventory", text)
        self.assertIn("needs.ready_scope.result == 'success'", job_block(text, "linux-build"))
        self.assertIn("needs.ready_scope.result != 'success'", job_block(text, "linux-regression-gate"))
        self.assertIn("case_profile_manifest_sha256", job_block(text, "linux-regression-gate"))

    def test_manual_diagnostics_are_not_cancelled_by_later_dispatch(self):
        for name in (
            "native.yml",
            "gdextension.yml",
            "documentation.yml",
            "issue49-water-apparatus.yml",
            "ci-validation.yml",
            "web-acceptance.yml",
        ):
            with self.subTest(name=name):
                text = workflow(name)
                self.assertIn("github.event_name == 'workflow_dispatch' && github.run_id", text)
                self.assertIn("cancel-in-progress: ${{ github.event_name != 'workflow_dispatch' }}", text)


if __name__ == "__main__":
    unittest.main()
