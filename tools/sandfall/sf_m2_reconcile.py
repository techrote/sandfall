#!/usr/bin/env python3
"""SF-M2 fresh-build-only reconciliation; original M0 errors remain untouched.

The new edit-adapter registration invalidates two additional old desktop input
entries. This does NOT qualify either desktop binary. Only the exact reviewed
registration delta may explain these two additional errors; any other error,
missing expected failure, changed runtime manifest or missing LFS payload refuses.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.sandfall import sf_m0_reconcile as m0
BASE = 'ba7add4de9fe8027aaedeff0fa703c1a55fee21e'
REGISTRATION = 'godot/native_extension/register_types.cpp'
NEW_ERRORS = frozenset(p + ' requires rebuild for source input: ' + REGISTRATION for p in m0.DESKTOP_PLATFORMS)
EXPECTED = m0.EXPECTED | NEW_ERRORS


def registration_delta(baseline: bytes) -> bytes:
    if baseline.count(b'#include "cyber_demo_bridge.hpp"\n') != 1 or baseline.count(b'    GDREGISTER_CLASS(CyberDemoBridge);\n') != 1:
        raise ValueError('Pinned registration anchors differ')
    return baseline.replace(b'#include "cyber_demo_bridge.hpp"\n', b'#include "cyber_demo_bridge.hpp"\n#include "sandfall_edit_bridge.hpp"\n').replace(b'    GDREGISTER_CLASS(CyberDemoBridge);\n', b'    GDREGISTER_CLASS(CyberDemoBridge);\n    GDREGISTER_CLASS(SandfallEditBridge);\n')


def classify(record: dict, source_checks: dict) -> dict:
    original = record['original_checker']
    errors = original.get('errors', [])
    result = dict(record)
    result.update(schema='sandfall-sf-m2-fresh-build-reconciliation-v1',
                  scope='six inherited refs + eight inherited desktop drifts + two exact SF-M2 registration drifts; fresh rebuild only, no desktop execution qualification',
                  inherited_documentation_failures=6, inherited_stale_desktop_digests=8,
                  new_registration_desktop_digests=sorted(NEW_ERRORS), source_checks=source_checks,
                  original_m0_disposition=record['status'],
                  unexpected_errors=sorted(set(errors)-EXPECTED),
                  missing_expected_errors=sorted(EXPECTED-set(errors)))
    safe = (record['checker_exit'] == 1 and original.get('status') == 'failed'
            and len(errors) == len(EXPECTED) and set(errors) == EXPECTED
            and set(original.get('documentation', {}).get('errors', [])) == m0.EXPECTED_DOC_ERRORS
            and record['current_lfs_count'] == 18 and not original.get('unmaterialized_runtime_files')
            and source_checks.get('exact_registration_delta') is True
            and source_checks.get('unchanged_runtime_payloads_and_manifests') is True
            and source_checks.get('unchanged_native_core') is True)
    result['safe_for_fresh_web_build'] = safe
    result['status'] = 'known_stale_desktop_inputs_retained_for_fresh_build_only' if safe else 'refused'
    return result


def run(root: Path, output: Path) -> int:
    baseline_output = output.with_name(output.stem+'-original-m0-refusal.json')
    m0.run(root, baseline_output)
    original = json.loads(baseline_output.read_text())
    checks = {}
    try:
        def git(*args: str) -> bytes:
            return subprocess.check_output(['git','-C',str(root),*args], stderr=subprocess.PIPE)
        baseline = git('show',BASE+':'+REGISTRATION)
        current = (root/REGISTRATION).read_bytes()
        checks = {'baseline':BASE, 'registration_sha256':hashlib.sha256(current).hexdigest(),
                  'exact_registration_delta':current == registration_delta(baseline),
                  'unchanged_runtime_payloads_and_manifests':not git('diff','--name-only',BASE,'--','godot/addons/cybersand_native').strip(),
                  'unchanged_native_core':not git('diff','--name-only',BASE,'--','native','Makefile').strip()}
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        checks['error'] = str(exc)
    result = classify(original, checks)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'status':result['status'],'expected_errors':16,'inherited_refs':6,'inherited_desktop_drifts':8,
                      'new_registration_desktop_drifts':2,'unexpected_errors':result['unexpected_errors'],
                      'missing_expected_errors':result['missing_expected_errors'],'source_checks':checks}))
    return 0 if result['safe_for_fresh_web_build'] else 1


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=ROOT)
    parser.add_argument('--output',type=Path,default=ROOT/'sf-m2-evidence/reconciliation.json')
    args=parser.parse_args()
    raise SystemExit(run(args.root.resolve(),args.output.resolve()))
