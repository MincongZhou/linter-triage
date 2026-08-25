# PT-039 — a finding code is missing a word

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `08-hygiene` — Descriptions, citations, severities and tests |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

- **#191** — Typos in reference for validation errors in en_319_412_1 *(closed)*
  **related.** As PT-037. Verified still present in the pinned v0.13.3: ts_119_312.py:21 still reads rsa_exponent_of_range.

## Analysis

```python
VALIDATION_RSA_EXPONENT_OUT_OF_RANGE = validation.ValidationFinding(
    validation.ValidationFindingSeverity.NOTICE,
    "ts_119_312.6.2.2.1.rsa_exponent_of_range",
)
```

The attribute is `…_OUT_OF_RANGE`, the message it raises reads "RSA public key
has an exponent of {n}", and the clause it cites states a range the exponent
must be *inside*. The code says `of_range`. It is the only spelling of the
name in the repository:

```
$ grep -rn "rsa_exponent_of_range\|rsa_exponent_out_of_range" --include=*.py --include=*.csv .
pkilint/etsi/ts_119_312.py:21:        "ts_119_312.6.2.2.1.rsa_exponent_of_range",
```

### Fix

Rename to `ts_119_312.6.2.2.1.rsa_exponent_out_of_range`. **A finding code is
interface** — downstream consumers filter and map on it — so this is a
breaking change and belongs in a major release, which is the only reason it is
worth recording rather than just fixing.

### Severity

**Low**: it misleads a reader and changes no verdict.

## What this lane examined and did not find a defect in

Recorded so the ratio in the reproduction beside this file counts refutations
as examination.

- **`etsi.en_319_411_1.gen-6.3.3-12.*`** — both sites match GEN-6.3.3-12 as written, in v1.1.1 and in v1.5.1. The `[CHOICE]` is over the document's seven policies, each bullet names one reserved identifier from clause 5.3, and choosing the bullet from the CA/Browser Forum validation type rather than from the ETSI identifier is the only ordering that can ever report anything. The requirement really is NAT-4.3.2-1, applied by reference. pkilint's own fixture `tests/integration_certificate/etsi/ncp_legal_person_certificate/crl_critical.crttest` expects exactly this pairing. - **`ts_119_312.8.4.rsa_small_modulus`'s 1 900-bit floor and `6.2.2.1`'s 2^16 < e < 2^256 window.** Both match table 6 and clause 6.2.2.1 of TS 119 312 **v1.5.1 (2024-12)** and of **v2.1.1 (2026-06)**; the two editions differ only in the recommended end date (2028-12-31 → 2026-12-31), which is not a certificate-checkable threshold. pkilint 0.13.3 was released 2026-04-23, six weeks before v2.1.1 was published, and its permitted algorithm lists carry no EdDSA and no post-quantum scheme, both of which v2.1.1 introduces — so it implements a 1.x edition and the choice makes no difference to either check.
