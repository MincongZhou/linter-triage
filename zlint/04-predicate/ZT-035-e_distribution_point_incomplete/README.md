# ZT-035 — `e_distribution_point_incomplete` gates the general rule behind the special case

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool |
| **Cases** | positive/ |
| **Verified against** | fabricated (recipe in the script) |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

Observed `pass`; correct `error`.

RFC 5280 §4.2.1.13 requires a `DistributionPoint` to contain either
`distributionPoint` or `cRLIssuer`, unconditionally. The lint errors only when
`dp.Reason.BitLength != 0` as well. A `DistributionPoint` with no fields has
`BitLength == 0`, so the condition is false and the certificate passes.

Fix: drop the `dp.Reason.BitLength != 0` conjunct.
