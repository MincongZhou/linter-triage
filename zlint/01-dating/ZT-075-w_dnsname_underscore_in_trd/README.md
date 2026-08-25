# ZT-075 — `w_dnsname_underscore_in_trd`'s `EffectiveDate` predates the requirement by over a decade

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```go
lint.RegisterCertificateLint(&lint.CertificateLint{
    LintMetadata: lint.LintMetadata{
        Name:          "w_dnsname_underscore_in_trd",
        Description:   "DNSName MUST NOT contain underscore characters",
        Citation:      "BRs: 7.1.4.2.1",
        Source:        lint.CABFBaselineRequirements,
        EffectiveDate: util.RFC5280Date,
    },
    ...
```

`util.RFC5280Date` is 2008-05-01. The citation is a CABF Baseline Requirements
clause, but the requirement it names did not exist in 2008.

**observed**: fires a warning on any subscriber certificate (issued from
2008-05-01) whose subject commonName or SAN dNSName contains an underscore in
the "TRD" (subdomain) portion, above the registrable domain. **correct**: BR
§7.1.4.2.1's underscore prohibition originates at **Ballot SC-12, BR 1.6.2**,
confirmed directly in `Policies/historical/br/br-1.6.2.txt`: a transitional
MAY-issue window opens 2018-12-10, and "After April 30, 2019, underscore
characters ('_') MUST NOT be present in dNSName entries." Nothing in any BR
edition before 1.6.2 restricts underscore characters in a dNSName. Confirmed
independently by this lane's own port,
`cabf_br/e_underscore_not_permissible_in_dnsname` (ported in an earlier wave,
carrying `CABFBRs_1_6_2_UnderscorePermissibilitySunsetDate` — 2019-04-01 — and
the transition window's own 2018-12-10 opening), whose REASONING.md
independently derives the same history from the same source.

**mechanism**: a `time.go` constant substitution — the citation names a BR
clause, but the effective date used is `util.RFC5280Date` rather than a
BR-history-derived constant such as `util.CABFBRs_1_6_2_Date`. Not a
control-flow question; settled by reading the Go source and by reading the
Baseline Requirements archive, per this skill's standard for a dating claim.

**Reproduction**, against zlint's own fixture:

```
$ zlint -includeNames w_dnsname_underscore_in_trd \
    
{"w_dnsname_underscore_in_trd":{"result":"warn"}}
$ openssl x509 -in  -noout -dates
notBefore=Aug 27 16:35:51 2017 GMT
notAfter=Nov  8 17:35:51 2017 GMT
```

Issued 2017-08-27 — sixteen months before SC-12's transitional window even
opens, and twenty months before the prohibition binds outright. zlint's own
fixture for this lint predates the requirement the lint is supposed to be
testing. This is the strongest form of reproduction the gap-reporting skill
names: the tool failing on its own test data.

subscriber certificates issued before 2018-12-10 whose SAN carries a dNSName
with an underscore anywhere finds **128** candidates — an over-count relative
to this lint's specific TRD-only predicate (it does not restrict to the TRD
label, and includes several more of zlint's own deliberately-dated test
fixtures), but the exact reproduction above is inside that set and is not a
constructed edge case.

```python
# for each corpus cert issued before 2018-12-10 (datetime), check any SAN
# DNSName for an underscore character
```

See this lane's ledger entry for `w_dnsname_underscore_in_trd`: verdict
`answered`, not `ported` — the existing identifiers cover a *superset* of this
predicate (every label, not just the TRD label) at the *correct* date, so no
new rule was written.
