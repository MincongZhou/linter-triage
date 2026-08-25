# ZT-021 — `e_signature_algorithm_not_supported` is undated and reports pre-Baseline-Requirements certificates

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ |
| **Verified against** | `md5WithRSASignatureAlgorithm.pem`, a GlobalSign certificate from January 1999 |

## Upstream issues, adjudicated

- **#326** — e_signature_algorithm_not_supported should warn not err for RSA PSS *(closed)*
  **related.** Same lint. #326 is about its severity for RSASSA-PSS; this entry is about it carrying no effective date at all.

## Analysis

```go
Citation:      "BRs: 6.1.5",
EffectiveDate: util.ZeroDate,

func (l *signatureAlgorithmNotSupported) CheckApplies(c *x509.Certificate) bool {
	return true
}
```

No date in either place one can be written. The Baseline Requirements took
effect 2012-07-01; **56 of this lint's 75 firings are on certificates issued
before that**, the oldest an MD5 certificate from 1999-01-28 — thirteen years
early, under a citation to a document that did not exist.

MD5 is genuinely unacceptable and the judgement is not in dispute. The defect
is that the finding cites a document which did not bind the certificate. RFC
5280 is what reaches a certificates, and that is a different shelf.

**Five of them are dated anyway**, inside `CheckApplies`:

```go
// e_old_root_ca_rsa_mod_less_than_2048_bits
return ok && … && issueDate.Before(util.NoRSA1024RootDate)
// e_rsa_mod_less_than_2048_bits
return ok && … && util.OnOrAfter(c.NotAfter, util.NoRSA1024Date)
```

Distinct from [ZT-044](#zl-031), which is about the same lint escalating
RSASSA-PSS from its own warning to an error. Same lint, different defect,
independent reproductions.

Fix: `EffectiveDate: util.CABEffectiveDate`.
