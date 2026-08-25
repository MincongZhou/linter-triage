# ZT-077 — `w_sub_cert_sha1_expiration_too_long` has no `IneffectiveDate`, double-reporting a MUST NOT violation as a SHOULD NOT

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
        Name:          "w_sub_cert_sha1_expiration_too_long",
        Citation:      "BRs: 7.1.3",
        Source:        lint.CABFBaselineRequirements,
        EffectiveDate: util.CABFBRs_1_2_1_Date,
    },
    ...
```

`CABFBRs_1_2_1_Date` (2015-01-16) is this guidance's own opening date, but
there is no closing date. Ballot 118's own hard cliff — SHA-1 issuance
prohibited outright — is 2016-01-01, which zlint's own
`e_sub_cert_or_sub_ca_using_sha1` reports at error. A SHA-1 subscriber
certificate issued after the cliff with an expiry past 2017-01-01 draws
**both** lints from zlint: the MUST NOT violation at error, and the SHOULD NOT
guidance at warning, for a requirement the MUST NOT has already superseded.

**Reproduction**, against a certificate this lane built specifically to
demonstrate this rule's own gate boundary (, issued 2018-01-01, SHA-1, expiry
2018-06-01 — four years past the ballot 118 cliff):

```
$ zlint -includeNames w_sub_cert_sha1_expiration_too_long,e_sub_cert_or_sub_ca_using_sha1 \
    
{"e_sub_cert_or_sub_ca_using_sha1":{"result":"error"},
 "w_sub_cert_sha1_expiration_too_long":{"result":"warn"}}
```

**Not ported as zlint states it.** This lane's rule carries
`Gate::IssuedBetween((2015,1,16), (2016,1,1))`, closing at the ballot 118
cliff, implementing the clause rather than the code.

certificates signed with a SHA-1 algorithm, issued on or after 2016-01-01,
with `notAfter` later than 2017-01-01, finds **51** candidates — every one of
which zlint's ungated lint would additionally warn about, beside the error its
own sibling already reports.
