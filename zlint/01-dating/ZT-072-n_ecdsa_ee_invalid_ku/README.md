# ZT-072 — `n_ecdsa_ee_invalid_ku` is dated from a document it does not cite

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | added by the integrator while porting the site |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```go
Citation:      "RFC 5480 Section 3",
Source:        lint.RFC5480,
EffectiveDate: util.CABEffectiveDate,
```

`util.CABEffectiveDate` is 2012-07-01, the day the CA/Browser Forum Baseline
Requirements took effect. RFC 5480 is March 2009. The two documents are
unrelated: the Forum's ballot did not bring RFC 5480 into force and RFC 5480
binds certificates the Baseline Requirements never governed.

The consequence is a three-and-a-third-year hole. A certificate issued between
March 2009 and July 2012 asserting, say, `cRLSign` on an elliptic-curve
end-entity key is outside a requirement that was in force the whole time, and
zlint returns `NE` rather than judging it.

**Reproduction** —, notBefore 2011-10-22, already in this tree:

```
zlint -includeNames n_ecdsa_ee_invalid_ku 
{"n_ecdsa_ee_invalid_ku":{"result":"NE"}}
```

**One-line fix**: `EffectiveDate: util.RFC5480Date`, a constant `util/time.go`
does not yet carry. Worth checking every other `Source: lint.RFC5480` and
`lint.RFC8813` lint for the same borrowed constant while the file is open —
this was found by comparing one lint's date against its own citation, which is
not a check anything in zlint performs.

**Why this is Medium and ZT-088 is Low.** Both are one lint reporting the
wrong thing. This one silently declines to judge a bounded population, which
is the shape that reads as conformance nobody verified; the other adds a
notice a reader can see and dismiss.
