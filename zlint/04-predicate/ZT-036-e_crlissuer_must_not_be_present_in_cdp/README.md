# ZT-036 — `e_crlissuer_must_not_be_present_in_cdp` cannot see the shape its body checks

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool |
| **Cases** | positive/ |
| **Verified against** | fixture `v3/testdata/crlIncomlepteDp.pem` |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

The guard is `c.CRLDistributionPoints != nil`, which zcrypto populates only
from `fullName` URIs. `Execute` re-decodes the raw extension and errors on a
`cRLIssuer` or `reasons` field. A `DistributionPoint` carrying only `reasons`
has no `fullName`, so nothing is extracted, the slice stays nil, and the lint
returns `NA` — the shape the body catches is the shape the guard filters out.

Fix: guard on `util.IsExtInCert(c, util.CrlDistOID)`.
