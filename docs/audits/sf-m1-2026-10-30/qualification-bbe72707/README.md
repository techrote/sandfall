# Retained SF-M1 qualification at bbe72707

The qualified application and harness source is
`bbe72707aa679790b66a143a71c09e7f21570993`. GitHub Actions
[run 41139800406](https://github.com/techrote/sandfall/actions/runs/41139800406)
finished successfully. The [dated audit](../../2026-10-30-sf-m1-host-input.md)
separates each gate, exact artifact identity and outstanding scope.

The [manifest](manifest.json) lists every retained payload's original SHA-256 and
size, plus its stored SHA-256 and size. Large JSON and logs use ordinary gzip
with deterministic headers; decompression reproduces the original artifact
bytes. PNGs and smaller receipts are retained directly. Compression changes no
evidence values. The complete runnable Web exports remain downloadable Actions
artifacts; this directory keeps both build identities and the dedicated export's
complete manifest.

| Gate | Retained original evidence |
|---|---|
| Ordinary 800×450 / DPR1 | [screenshot](ci/ordinary-dpr1/browser.png), [full observations](ci/ordinary-dpr1/browser.json.gz), [artifact verification](ci/ordinary-dpr1/artifact-verification.json) |
| Ordinary 640×400 / DPR2 | [screenshot](ci/ordinary-dpr2/browser.png), [full observations](ci/ordinary-dpr2/browser.json.gz), [artifact verification](ci/ordinary-dpr2/artifact-verification.json) |
| Fresh build / actual Godot tests | [complete build and test log](ci/build-evidence/sandfall-build-and-godot-tests.log.gz) |
| Focused native | [source/input/test receipt](ci/source-native/native-focused/receipt.json.gz) |
| Retained legacy 600-tick functional contract | [browser observations](ci/legacy-contract/browser.json.gz), [log with screenshot timeout](ci/legacy-contract/harness.log.gz) |
| Narrow provenance reconciliation | [original checker failures](ci/docs/documentation-reconciliation.json) |
| Independent ordinary review | [review receipt](review/ordinary-evidence-review.json) |
| Independent final source/evidence review | [review receipt](review/independent-final-review.json) |
| First failed fresh export | [original CI log](negative/3be-export/sandfall-build-and-godot-tests.log.gz) |
| Local incomplete-PCK inventory refusals | [dedicated refusal](negative/local-packaging/artifact-verification-local-residue.json), [explicit packaging receipt](negative/local-packaging/packaging-receipt.json), [legacy refusal](negative/local-packaging/legacy-export-verification.json) |

The legacy functional test completed all 600 paired ticks and pause/save/restore/
reset assertions, but its screenshot timed out. There is no legacy PNG in this
bundle. The dedicated ordinary runs provide the actual visual evidence.

Raw local temporary PCK bodies remain in the execution workspace and are not
distributable application files. Their names, complete digests, header evidence
and the original verifier refusals are retained here. The qualified export is
the clean CI artifact, not either refused raw local directory.

To verify retained payload integrity from this directory:

```python
from pathlib import Path
import gzip, hashlib, json

root = Path('.')
manifest = json.loads((root / 'manifest.json').read_text())
for item in manifest['files']:
    stored = (root / item['path']).read_bytes()
    assert len(stored) == item['stored_size']
    assert hashlib.sha256(stored).hexdigest() == item['stored_sha256']
    raw = gzip.decompress(stored) if item['encoding'] == 'gzip' else stored
    assert len(raw) == item['original_size']
    assert hashlib.sha256(raw).hexdigest() == item['original_sha256']
print('All retained original payloads verified')
```
