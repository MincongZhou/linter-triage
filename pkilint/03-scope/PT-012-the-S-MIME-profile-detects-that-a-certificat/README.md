# PT-012 — the S/MIME profile detects that a certificate is a CA, says so, and applies every Subscriber requirement anyway

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `03-scope` — Applied outside the population the clause governs |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ |
| **Verified against** | a real Apple issuing CA |

## Upstream issues, adjudicated

- **#13** — Unknown CN value source *(closed)*
  **related.** As PT-016.

## Analysis

Executed against `CN=Apple Public Client RSA CA 3 - G1`, `CA:TRUE, pathlen:0`,
valid 2024-08-14 to 2029-08-13, policy `2.23.140.1.5.2.2`:

```
certificate is_ca = True
determine_validation_level_and_generation() -> ORGANIZATION, MULTIPURPOSE
```

A Subscriber validation level and generation, for a CA certificate. pkilint
then reports, on that one certificate and together:

```
cabf.smime.is_ca_certificate
cabf.smime.certificate_validity_period_exceeds_825_days
cabf.smime.san_extension_missing
cabf.smime.common_name_value_unknown_source
cabf.smime.missing_required_attribute
cabf.smime.prohibited_attribute
cabf.smime.multiple_reserved_policy_oids
```

Only the first is right. **pkilint knows the certificate is a CA — it says so
in the same output — and applies the Subscriber profile regardless.** A
five-year validity is ordinary for an issuing CA; S/MIME BR § 6.3.2's 825-day
ceiling is a Subscriber requirement, as are a SAN, a commonName drawn from it,
and the attribute allow-lists.

| row | explained |
|---|---|
| `certificate_validity_period_exceeds_825_days` | **78 of 78** |
| `san_extension_missing` | 78 of 99 |
| `common_name_value_unknown_source` | 78 of 110 |
| `multiple_reserved_policy_oids` | 40 of 61 |
| `missing_required_attribute` | 40 of 58 |
| `prohibited_attribute` | 31 of 35 |

**Fix.** When `is_ca` is true, report `cabf.smime.is_ca_certificate` and stop.
