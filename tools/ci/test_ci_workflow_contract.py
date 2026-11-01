#!/usr/bin/env python3
"""Static trigger, source-identity and concurrency contracts for CI workflows."""

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

    def test_mainline_web_gate_reuses_source_matched_m3_workshop(self):
        wrapper = workflow("web-acceptance.yml")
        reusable = workflow("sf-m3-web.yml")
        build_script = (ROOT / "tools/sandfall/sf_m3_ci.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn(".github/workflows/web-acceptance.yml", wrapper)
        self.assertIn(".github/workflows/sf-m3-web.yml", wrapper)
        self.assertNotIn(".github/workflows/**", wrapper)
        self.assertIn("uses: ./.github/workflows/sf-m3-web.yml", wrapper)
        self.assertIn("routine: true", wrapper)
        self.assertIn("github.event.pull_request.draft == false", wrapper)
        self.assertIn("tools/build_web.py", wrapper)
        self.assertIn("tools/sandfall/**", wrapper)
        self.assertNotIn("tools/**", wrapper)
        self.assertIn("startsWith(github.head_ref, 'sf-m3/')", wrapper)
        self.assertIn("startsWith(github.head_ref, 'sf-m4/')", wrapper)
        self.assertIn("workflow_call:", reusable)
        self.assertIn("branches: ['sf-m3/**']", reusable)
        self.assertIn("if: ${{ !inputs.routine }}", reusable)
        self.assertEqual(
            reusable.count("ref: ${{ github.event.pull_request.head.sha || github.sha }}"),
            6,
        )
        self.assertNotIn("ref: ${{ github.sha }}", reusable)
        self.assertIn("for bodies in 0 1 3 8 16", reusable)
        self.assertIn("sf_m1_browser, sf_m2_browser", reusable)
        self.assertIn("--profile compat", build_script)
        self.assertIn("--native-cpp", build_script)
        self.assertIn("sf_m3_reconcile.py", build_script)
        self.assertIn("sf_m2_ci.sh", build_script)

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
