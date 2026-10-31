# SF-M2 source-qualified evidence custody

Qualified source: `533a3de6352074f0cd68faca94417e80f041080e`.

`manifest.json` binds every original artifact/run/head and original payload byte to its retained file. Original text payloads use deterministic gzip, preserving native trailing whitespace; decompression must match the original digest. PNGs are byte-preserved. Original and intermediate failures remain failures. The two verified-reuse cohorts execute harness 533a3de6 against build 3a008a55; the full-source cohort freshly builds and executes 533a3de6. Transport workflow heads do not replace embedded source identities.

The full-source API receipts and artifact inventory are retained separately. Runnable dedicated/legacy exports are not vendored here; their exact GitHub artifact IDs, original ZIP digests and expiry are in `full-source-artifacts.json`. After expiry, build and qualify a new source-matched export.

The legacy600 receipt is functional evidence and must not turn a missing screenshot into visual acceptance. The dedicated ordinary lanes provide original PNGs. Broad desktop/threaded/unisolated-hosting and owner human visual acceptance remain separate. Historical 164-test native results are not newly executed full SF-M2 tests.

`independent-recomputation.json` is a derived local verification of the earlier passing reused-artifact cohort, not a fabricated original runner receipt.
