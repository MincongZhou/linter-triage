# PT-013 — a self-issued certificate is a root CA whatever its basicConstraints says

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | `pkilint./repro.sh` (subject + control, one name apart, same linter, NOTICE floor) |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

`determine_certificate_type` tests self-issuance first and returns before the
basic constraints are ever read:

```python
def determine_certificate_type(cert):
    if cert.is_self_issued:
        return serverauth_constants.CertificateType.ROOT_CA

    if cert.is_ca:
        return _determine_intermediate_ca_type(cert)
    ...
```

and `is_self_issued` is nothing but a DER comparison of the two names:

```python
return encode(issuer_node.pdu) == encode(subject_node.pdu)
```

So **a self-signed end-entity certificate is judged against the root CA
profile**. The two fixtures differ in the issuer name and in nothing else —
both carry `basicConstraints` `cA:FALSE`, an `extendedKeyUsage` of
`serverAuth`, a `dNSName` SAN and the domain-validated reserved policy
identifier:

```
negative/PT-013-control.pem       issuer != subject
  DV-FINAL-CERTIFICATE
    cabf.serverauth.dv.common_name_attribute_present (WARNING)

positive/PT-013-self-issued.pem   issuer == subject
  ROOT-CA
    cabf.serverauth.root_validity_period_too_short (ERROR): 151 days is below 2922
    cabf.serverauth.ca.organization_name_attribute_absent (ERROR)
    cabf.serverauth.ca_basic_constraints_ca_bit_not_set (ERROR)
    cabf.serverauth.root_basic_constraints_ca_not_present (ERROR)
    cabf.ca_certificate_required_ku_missing (ERROR): keyCertSign not asserted
    cabf.serverauth.root.extended_key_usage_extension_present (ERROR)
    cabf.serverauth.root.subject_key_identifier_extension_absent (ERROR)
```

**observed** — every finding on the second is wrong about the certificate in
front of it. Its validity period is 151 days, which is what a *subscriber*
certificate must be and four-fifths of what a root must not be; a DV subject
`MUST NOT` carry the `organizationName` it is faulted for lacking; the `cA`
bit is not set because it is not a CA. Every subscriber check is skipped in
exchange, including the 398-day maximum, the SAN profile and the DV subject
table.

**correct** — consult `basicConstraints` before choosing the profile. RFC 5280
§4.2.1.9 is explicit that a key whose certificate omits the extension or sets
`cA` FALSE "MUST NOT be used to verify certificate signatures", so such a
certificate is not a CA whatever its issuer name; BR §7.1.2.1 requires a Root
CA certificate to carry `basicConstraints`, critical, with `cA` TRUE.

**The information is not missing, and pkilint prints it.** `is_ca` is `False`
on the same document — the reproduction dumps both accessors — and the run
itself reports `ca_basic_constraints_ca_bit_not_set` from
`CaBasicConstraintsValidator`. pkilint reads the field that would settle the
question, reports it as an error, and does not act on it. That also
distinguishes this from [`PT-032`](#pk-005), where the deciding field could
not be read at all: here it was read.

It contradicts the tool's own description too. `--detect`'s help text is
"Detect the type of certificate from reserved CA/B Forum policy OID, EKU(s),
name constraints, **and basic constraints**" — and for a self-issued
certificate the basic constraints are never consulted.

**Why High: the subject decides which checks run.** Setting `issuer` equal to
`subject` switches off the entire subscriber profile. That is not a hostile
manoeuvre a CA would attempt, but it is the property that separates this class
from a merely absent check, and self-signed certificates are ordinary in CT.
