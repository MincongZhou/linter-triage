# ZT-022 — `e_subject_not_dn` is a tautology and can never fire

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `02-unreachable` — Checks that cannot fire |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ |
| **Verified against** | settled by execution |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```
static type of Certificate.Subject : pkix.Name
reflect.TypeOf(c.Subject)          : pkix.Name
reflect.TypeOf(*(new(pkix.Name)))  : pkix.Name
predicate (Error branch taken?)    : false
```

A dead lint reporting RFC 5280 §4.1.2.6 as covered. The checkable content is
in `c.RawSubject`, not in the static type of the field the decoder wrote into.
