# ZT-069 — `e_crl_extensions_validity` returns two severities, and is undated for a 2023 table

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl, python3, a checkout of the tool (the script reads its source) |
| **Cases** | positive/ |
| **Verified against** | a real 2019 incident CRL |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```
$ zlint -format der positive/ZT-069-crl-2019.crl        # Last Update: May 3 2019
e_crl_extensions_validity = warn
  CRL Extension 2.5.29.60 is NOT RECOMMENDED
```

Two problems in one lint, and the output above shows both: a `warn` from a
lint named `e_`, about a table that did not exist in 2019.

**One identifier, two severities.** `Execute` has two loops. The first returns
`lint.Warn` for an extension outside § 7.2.2's three; the second returns
`lint.Error` for one of the three carrying the wrong criticality. zlint's own
contributor guide states the rule this breaks: *"Lints only return one
non-success or non-fatal status, which must also match their name prefix."* A
caller selecting `e_` lints gets warnings, and one filtering by severity
cannot select half a lint.

**No effective date.** The `LintMetadata` block carries `Name`, `Description`,
`Citation` and `Source` and no `EffectiveDate`, which the framework reads as
*always*. § 7.2.2's extension table is ballot SC-63's, Baseline Requirements
1.8.7, effective 2023-07-15 — and `util.CABFBRs_1_8_7_Date` already exists and
is what the sibling CRL lints use. This is the class [`another entry
here`](certlint.md#cl-004) reports against cablint.

**Fix** — two registered lints, `e_` for the criticality MUST and `w_` for the
NOT RECOMMENDED row, and `EffectiveDate: util.CABFBRs_1_8_7_Date` on both.
