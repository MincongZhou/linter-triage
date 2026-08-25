# ZT-034 — `e_sub_cert_cert_policy_empty` passes the empty extension it names

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool |
| **Cases** | positive/ |
| **Verified against** | fixture `v3/testdata/empty_seq_of_cps.pem` |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

Observed `pass`; correct `error`.

The guard is `util.IsExtInCert(c, util.CertPolicyOID) && c.PolicyIdentifiers
!= nil`. zcrypto sets `PolicyIdentifiers` to a **non-nil zero-length** slice
for an empty `SEQUENCE OF`, so the guard holds and the lint returns `Pass` for
a certificate asserting no policy identifier — contradicting its own
Description.

Fix: `len(c.PolicyIdentifiers) > 0`. zlint's own fixture demonstrates it and
no test asserts `Error` on it.
