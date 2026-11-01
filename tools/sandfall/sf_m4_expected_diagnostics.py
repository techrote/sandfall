"""Admit only the pinned inflater's precise, witnessed hostile-input diagnostic.

Godot 4.7 reports malformed DEFLATE/CRC through an error-return AND an engine
diagnostic. This exception is confined to named negative tests, never ordinary
execution. The original output remains intact. Unknown errors, failed refusal,
changed input/candidate, absent terminal success or unmatched boundaries fail.
"""
from __future__ import annotations

import json
import re

BEGIN = "SF_M4_EXPECTED_DECOMPRESSION_REFUSAL_BEGIN "
END = "SF_M4_EXPECTED_DECOMPRESSION_REFUSAL_END "
CASES = {
    "test_sandfall_archive.gd": {"reserved_deflate_block", "truncated_deflate",
        "deflate_output_exceeds_declared_bound", "deflate_crc_mismatch"},
    "test_sandfall_archive_interop.gd": {"external_crc"},
}
RESULT = {"test_sandfall_archive.gd": "SANDFALL_ARCHIVE_TEST ",
          "test_sandfall_archive_interop.gd": "SF_M4_INTEROP_RESULT "}


def validate(output: str, script: str) -> list[dict]:
    """Return exact retained negative diagnostic receipts or raise ValueError."""
    if script not in CASES:
        raise ValueError("Engine error outside an explicit SF-M4 archive negative suite")
    active, receipts, seen, terminal = None, [], set(), False
    for raw in output.splitlines():
        line = re.sub(r"\x1b\[[0-9;]*m", "", raw).strip()
        if line.startswith(BEGIN):
            if active is not None or terminal:
                raise ValueError("Nested or post-terminal archive diagnostic boundary")
            value = json.loads(line[len(BEGIN):])
            if set(value) != {"case", "fixture_sha256"} or value["case"] not in CASES[script] or value["case"] in seen:
                raise ValueError("Unknown or repeated expected archive diagnostic case")
            if not re.fullmatch(r"[0-9a-f]{64}", str(value["fixture_sha256"])):
                raise ValueError("Expected diagnostic has no exact fixture hash")
            active = {**value, "diagnostics": []}
            seen.add(value["case"])
        elif line.startswith(END):
            value = json.loads(line[len(END):])
            if active is None or set(value) != {"case", "fixture_sha256", "refused", "error", "input_unchanged", "retained_candidate_unchanged"}:
                raise ValueError("Unmatched or malformed archive diagnostic closure")
            if value["case"] != active["case"] or value["fixture_sha256"] != active["fixture_sha256"]:
                raise ValueError("Archive diagnostic closure identifies a different fixture")
            if value["refused"] is not True or value["input_unchanged"] is not True or value["retained_candidate_unchanged"] is not True:
                raise ValueError("Expected malformed archive was accepted or changed retained data")
            if value["error"] != "zip_decompression_size_or_crc" or active["diagnostics"] != ["ERROR: Decompression failed."]:
                raise ValueError("Expected archive diagnostic/refusal does not match the pinned engine")
            receipts.append({**active, "refusal": value})
            active = None
        elif "ERROR:" in line:
            if active is None or line != "ERROR: Decompression failed.":
                raise ValueError("Unexpected Godot error: " + line)
            active["diagnostics"].append(line)
        elif line.startswith(RESULT[script]):
            value = json.loads(line[len(RESULT[script]):])
            if active is not None or terminal or value.get("failures") != [] or not isinstance(value.get("checks"), int) or value["checks"] <= 0:
                raise ValueError("Archive negative suite did not finish successfully")
            if script.endswith("_interop.gd") and value.get("status") != "passed":
                raise ValueError("External ZIP interchange did not pass")
            if script == "test_sandfall_archive.gd" and value.get("ok") is not True:
                raise ValueError("Archive negative suite did not report an explicit passing verdict")
            terminal = True
    if active is not None or not terminal or seen != CASES[script]:
        raise ValueError("Incomplete or missing witnessed malformed DEFLATE matrix")
    return receipts
