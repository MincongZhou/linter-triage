# XT-006 — the TLS subscriber profile is applied to delegated OCSP responders

| | |
|---|---|
| **Tool** | `kroeckx/x509lint` at `103c92f` |
| **Group** | `03-scope` — Applied outside the population the clause governs |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ |
| **Verified against** | zlint's own conforming fixture |

## Upstream issues, adjudicated

- **#35** — id-kp-clientAuth certificates incorrectly trigger ERR_POLICY_BR  *(closed)*
  **related.** Closed. The same class of defect -- a Baseline Requirements profile applied to a certificate the BRs do not govern -- reported for clientAuth-only certificates. This entry is delegated OCSP responders.
- **#29** — Don't LINT certificates that are not SSL/TLS against BRGs *(closed)*
  **related.** 'Don't LINT certificates that are not SSL/TLS against BRGs', closed. The general form of the same complaint; still reproduces for this population.

## Analysis

```
$ x509lint 
E: No policy extension
E: No CRL or OCSP over HTTP
E: no authorityInformationAccess extension
```

The file is zlint's positive fixture for a delegated OCSP responder —
`extKeyUsage` is `id-kp-OCSPSigning` alone, `id-pkix-ocsp-nocheck` is present,
and zlint's own test table declares it **Pass** for
`e_ocsp_cert_cdp_forbidden` and `e_ocsp_cert_cp_forbidden`. The absences
x509lint reports as errors are what the profile requires.

Baseline Requirements § 7.1.2.8.2, *OCSP Responder Extensions*:
`certificatePolicies` **SHOULD NOT**, `authorityInformationAccess` **NOT
RECOMMENDED** (§ 7.1.2.8.3 gives the reason), `crlDistributionPoints` **MUST
NOT** via § 7.1.2.11.2, `subjectAltName` **MUST NOT**. The third error cannot
be satisfied at all: the only two carriers of a revocation pointer are the two
the profile forbids or discourages.

Mechanism. `GetType` returns `SubscriberCertificate` for anything
`X509_check_ca` does not call a CA (`checks.c:1922`), and every Baseline
Requirements check keys on that one value — `ERR_NO_POLICY` at `checks.c:909`,
`ERR_NO_AIA` at `1351`, `ERR_NO_REVOCATION_HTTP` at `1375`. x509lint's only
profile axis is leaf / intermediate CA / root CA; it has no notion of the
*purpose* profile the Forum imposes on a leaf, so requirements written for a
TLS server certificate are applied to delegated OCSP responders, and to
S/MIME, timestamping and code signing certificates that other documents
profile or that no Forum document profiles at all.

Fix: gate `CheckPolicy`, `CheckAIA` and `CheckRevocationOverHTTP` on
`GetCertInfo(CERT_INFO_SERV_AUTH)` as well as `type == SubscriberCertificate`.
The general form is a purpose axis derived from `extKeyUsage`, set once in
`CheckEKU` and consulted by every check whose citation is a Baseline
Requirements clause.
