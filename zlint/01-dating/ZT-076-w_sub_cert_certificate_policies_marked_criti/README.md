# ZT-076 — `w_sub_cert_certificate_policies_marked_critical` has no `IneffectiveDate`, understating severity after BR 2.0.0

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | same mechanism as `ZT-073` |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

The subscriber-scope sibling of the CA-scope finding the reproduction beside
this file already recorded as `ZT-073`, same file:

```go
lint.RegisterCertificateLint(&lint.CertificateLint{
    LintMetadata: lint.LintMetadata{
        Name:          "w_sub_cert_certificate_policies_marked_critical",
        Citation:      "BRs: 7.1.2.3",
        Source:        lint.CABFBaselineRequirements,
        EffectiveDate: util.CABEffectiveDate,
    },
    ...
```

**observed**: no `IneffectiveDate`, so a faithful translation would keep
warning about a critical `certificatePolicies` on a subscriber certificate
issued after BR 2.0.0 (2023-09-15), when §7.1.2.7.6's table restates the
requirement as **MUST NOT** — a MUST NOT violation zlint's own
`e_certificate_policies_marked_critical`-equivalent (a separate lint this lane
did not examine in zlint's own tree) would presumably also report, at error.
**correct**: the SHOULD NOT era and the MUST NOT era should not both be
reported at the SHOULD NOT lint's severity; the warning should close where the
error-level requirement opens.
