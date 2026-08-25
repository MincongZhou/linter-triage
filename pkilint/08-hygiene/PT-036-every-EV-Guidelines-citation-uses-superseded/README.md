# PT-036 — every EV Guidelines citation uses superseded numbering

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `08-hygiene` — Descriptions, citations, severities and tests |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | `pkilint./repro.sh [pkilint-source-dir]` |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

Eleven citations across four modules and twenty rows of `finding_metadata.csv`
use EVG §9.x numbering. EVG 2.0.0 restructured into RFC 3647 and section 9
became "OTHER BUSINESS AND LEGAL MATTERS", so six no longer resolve and four
resolve to unrelated clauses:

| cited | EVG 1.8.1 | EVG 2.0.3 |
|---|---|---|
| 9.2 | Subject Distinguished Name Fields | Financial responsibility |
| 9.2.3 | Subject Business Category Field | Insurance or warranty coverage |
| 9.2.6 | Subject Physical Address of Place of Business | absent |
| 9.7 | Additional Technical Requirements for EV | Disclaimers of warranties |
| 9.8.1 | Subject Alternative Name Extension | absent; now 7.1.2.1 |

A reader following the reference is misled rather than merely stranded, which
is why this is worse than a stale pointer.

Fix: renumber to 7.1.2.x / 7.1.4.2.x, or pin the version quoted the way zlint
does (`CABF EV Guidelines 1.7.8 Section 9.8.1`).
