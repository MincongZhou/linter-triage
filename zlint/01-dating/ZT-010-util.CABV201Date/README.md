# ZT-010 — `util.CABV201Date` is the effective date of a different ballot

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool |
| **Cases** | positive/ and negative/ |
| **Verified against** | fabricated pair |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

Observed `NE` for notBefore 2017-07-10; correct `error`.

`util/time.go:73` sets `CABV201Date = 2017-07-28`. Ballot 201 (".onion
Revisions", EVG 1.6.5) was adopted 2017-06-08 and took effect **2017-07-08**.
2017-07-28 is the effective date of the next row in the same table — ballot
192 / EVG 1.6.6, the Notary Revision, which concerns Latin Notaries. A row
slip, not an invented date.

It is the sole `EffectiveDate` of `e_ext_tor_service_descriptor_hash_invalid`,
so EV `.onion` certificates issued in those twenty days return `NE`.

Separately: the extension and its syntax date from ballot 144 / EVG 1.5.3,
effective 2015-02-18, so even the corrected constant leaves two years
unchecked.
