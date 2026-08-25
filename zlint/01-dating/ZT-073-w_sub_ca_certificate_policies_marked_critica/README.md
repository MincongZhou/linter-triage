# ZT-073 — `w_sub_ca_certificate_policies_marked_critical` has no `IneffectiveDate`, understating severity after BR 2.0.0

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | reproduction against a real corpus certificate |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```go
lint.RegisterCertificateLint(&lint.CertificateLint{
    LintMetadata: lint.LintMetadata{
        Name:          "w_sub_ca_certificate_policies_marked_critical",
        Description:   "Subordinate CA certificates certificatePolicies extension should not be marked as critical",
        Citation:      "BRs: 7.1.2.2",
        Source:        lint.CABFBaselineRequirements,
        EffectiveDate: util.CABEffectiveDate,
    },
    Lint: NewSubCACertPolicyCrit,
})
```

No `IneffectiveDate`. The framework therefore applies this lint's Warn verdict
to every certificate ever issued, including ones issued after BR 2.0.0 (SC-62,
effective 2023-09-15) restated the same requirement as **MUST NOT** (Tables 24
and 31), which zlint itself has no separate check for.

**observed**: zlint reports `w_sub_ca_certificate_policies_marked_critical`
(Warn) on a subordinate or root CA certificate with certificatePolicies marked
critical, whatever its issuance date. **correct**: from 2023-09-15, the same
defect is a MUST NOT violation — an error, not a warning — and zlint has no
lint that reports it at that severity for a certificate issued after that
date. A certificate that genuinely breaches the current profile is
under-reported by exactly one severity tier.

**mechanism**: absence of `IneffectiveDate` in the `LintMetadata` struct
literal, read directly — no execution needed to settle this claim, per the
skill's own distinction between a missing-field reading and a control-flow
ambiguity.
