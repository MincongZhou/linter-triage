# PT-035 — the severity catalogues have drifted from the code

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `08-hygiene` — Descriptions, citations, severities and tests |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | `pkilint./repro.sh` (standalone; enumerates `report.get_included_validations` over every certificate type each profile declares and diffs against `finding_metadata.csv`) |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

| profile | csv rows | live validations | stale rows | performed, absent from csv | severity disagreements |
|---|---:|---:|---:|---:|---:|
| serverauth | 325 | 336 | 15 | 26 | 0 |
| smime | 160 | 185 | 18 | 43 | 1 |
| **etsi** | **0** | **342** | — | **342** | — |

etsi's file is a header row and nothing else.

The one severity disagreement is
`cabf.smime.german_ntr_registration_reference_not_euid`: CSV `ERROR`, code
`WARNING`. Much of the rest is pure rename the CSV never followed —
`pkix.generalizedtime_incorect_syntax` → `..._incorrect_syntax`,
`pkix.certificate_signature_algorithm_match` → `..._mismatch`.

Fix: `tests/test_finding_metadata_csv_smoke.py` validates only the files'
shape — field names, no extra fields, no `None` — and iterates zero rows for
etsi without complaint. One test comparing each CSV against
`report.get_included_validations` would have caught all 102 discrepancies
including the severity one.

Consequence for anyone else: a catalogue pass driven by these files
understates what the tool performs, and for etsi reports nothing at all.
