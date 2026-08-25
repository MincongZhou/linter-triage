# PT-034 — a validator crashes where it should be skipped

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `07-robustness` — Panics, run-ending failures, and non-determinism |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool |
| **Cases** | positive/ |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

- **#137** — Unhandled exception when certificate uses md2WithRSAEncryption *(closed)*
  **follow-up.** Closed by handling unknown signature algorithms in AuthorityKeyIdentifierPresenceValidator. That validator still raises base.unhandled_exception here on a real trust-store root, so the fix did not reach this case.
- **#131** — Gracefully handle unsupported public key algorithms for AKI presence check *(closed)*
  **follow-up.** As #137: 'Gracefully handle unsupported public key algorithms for AKI presence check', closed, and the validator still raises.

## Analysis

A validator bound to a node that failed to decode still runs, navigates into
the absent child, and raises. pkilint catches it and emits
`base.unhandled_exception (FATAL)`, so nothing is silent — but the validator
produces no finding, and the message names a Python node path rather than a
requirement.

```
positive/PT-034-nonnist-curve.pem   EcdsaKeyValidator @ subjectPublicKeyInfo
  base.unhandled_exception (FATAL): Node with name "eCParameters" does not
  exist at "…algorithm.parameters" (requested path:
  "algorithm.parameters.eCParameters.namedCurve")

positive/PT-034-version4.pem        AuthorityKeyIdentifierPresenceValidator @ certificate
  base.unhandled_exception (FATAL): 3 is not a valid X509 version
```

**observed** — the validator raises; its check goes unperformed. **correct** —
skip a validator whose bound node failed to decode. pkilint *already knows*:
it emits `itu.invalid_asn1_syntax` for the same input, from the same run,
before the validator executes.

**Why this is worth reporting even though nothing is silent.** On
`positive/PT-034-nonnist-curve.pem` the validator that dies is
`EcdsaKeyValidator`, and the certificate is a real CA misissuance from a
certificate whose entire defect is a **non-NIST curve**. The check most
relevant to that certificate is the one that crashed. pkilint still reports
the certificate as defective, via the ASN.1 finding, so no verdict is wrong —
which is why this is Medium and not High.

Two smaller notes for a maintainer. The process exits **0** in both cases, so
a caller checking status sees success. And the second case originates in
`cryptography` rejecting version 4 inside `is_signed_with_key`, which means
the guard belongs at pkilint's boundary rather than in the validator.
