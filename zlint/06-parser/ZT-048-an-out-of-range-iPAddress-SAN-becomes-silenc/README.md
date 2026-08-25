# ZT-048 — an out-of-range `iPAddress` SAN becomes silence, not a finding

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `06-parser` — Root cause in the decoder, not in the check |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool |
| **Cases** | positive/ and negative/ |
| **Verified against** | fabricated pair |

## Upstream issues, adjudicated

- **#413** — Lint for nameConstraints for dNSName and iPAddress *(open)*
  **unrelated.** A feature request for nameConstraints lints on dNSName and iPAddress. This entry is about an out-of-range iPAddress SAN decoding to silence.
- **#591** — BUG: lint "e_ext_san_rfc822_name_present" should only be applied to SSL/TLS subscriber certificates *(open)*
  **unrelated.** About e_ext_san_rfc822_name_present being applied to CA certificates. Matched on the word iPAddress only.

## Analysis

```
three octets  fatal: "x509: certificate contained IP address of length 3"; 0 bytes JSON
four octets   parses; six findings
```

The constraint *is* enforced — at `zcrypto/x509/x509.go:1470`, as a hard parse
refusal. So the precise defect is not "no check" but that a nonconformity
becomes total silence rather than a finding. This is ZT-055 specialised.

The general shape, worth stating once: any requirement about a malformation
severe enough to stop a field decoding cannot be written over the decoded
form.
