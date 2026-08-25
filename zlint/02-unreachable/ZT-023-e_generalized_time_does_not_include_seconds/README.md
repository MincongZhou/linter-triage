# ZT-023 — two GeneralizedTime lints are unreachable by construction

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `02-unreachable` — Checks that cannot fire |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool |
| **Cases** | positive/ and negative/ |
| **Verified against** | fixtures `generalizedNoSeconds.pem`, `generalizedNoFraction.pem` |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

`e_generalized_time_does_not_include_seconds` and
`e_generalized_time_includes_fraction_seconds` describe certificates their own
parser refuses:

```
generalizedNoSeconds.pem   fatal: cannot parse "Z" as "05"
generalizedNoFraction.pem  fatal: time did not serialize back to the original value
```

One of the two does fire, on a certificate carrying neither malformation.
`e_generalized_time_includes_fraction_seconds` reports a fractional second on
a whole-second time bearing a positive UTC offset — see [ZT-038](#zl-016).
