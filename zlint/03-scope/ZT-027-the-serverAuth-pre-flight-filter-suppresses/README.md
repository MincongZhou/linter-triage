# ZT-027 — the serverAuth pre-flight filter suppresses BR-wide requirements

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `03-scope` — Applied outside the population the clause governs |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool |
| **Cases** | positive/ and negative/ |
| **Verified against** | fabricated pair, same 1024-bit key |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```
EKU=OCSPSigning  e_rsa_mod_less_than_2048_bits          NA
                 e_mp_modulus_must_be_2048_bits_or_more error
EKU=serverAuth   e_rsa_mod_less_than_2048_bits          error
```

The Mozilla-sourced lint fires on both, proving the certificate is
non-conformant and only the BR filter hides it. On a real delegated responder,
running each BR lint's own `CheckApplies`/`CheckEffective` against the
framework result shows **6 of 166 BR lints suppressed by the pre-flight filter
alone**, including key size and signature algorithm. BR §7.1.2.8 profiles this
certificate and points its `subjectPublicKeyInfo` row at §7.1.3.1.

Exactly four lints set `OverrideFrameworkFilter`, all four about OCSP
responders.
