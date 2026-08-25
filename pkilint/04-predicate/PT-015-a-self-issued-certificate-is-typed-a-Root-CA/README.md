# PT-015 — a self-issued certificate is typed a Root CA before anything asks whether it is a CA

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ |
| **Verified against** | zlint's own SAN test fixture |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

`pkilint/cabf/serverauth/__init__.py:92`:

```python
def determine_certificate_type(cert):
    if cert.is_self_issued:
        return CertificateType.ROOT_CA
    if cert.is_ca:
        return _determine_intermediate_ca_type(cert)
    ...
```

`is_self_issued` is tested first and `is_ca` is never consulted for a
self-issued certificate. They are independent properties and this treats one
as implying the other. Executed rather than read:

```
is_self_issued = True
is_ca          = False
determine_certificate_type() -> ROOT_CA
```

RFC 5280 § 4.2.1.9 is explicit — "If the basic constraints extension is not
present … then the certificate MUST NOT be used as a CA certificate."
Self-issuance is not CA-ness. A self-signed subscriber certificate is an
ordinary, if unusual, end-entity certificate, and the one in the reproduction
is zlint's own SAN fixture.

**The clearest consequence is circular.** The certificate is typed a Root CA
*because* it is self-issued, and is then reported under
`cabf.serverauth.root.basic_constraints_extension_absent` for lacking the very
extension whose absence means it is not a CA.

**111 are not CAs** — verified with `openssl`, counting `CA:TRUE` rather than
inferring.

| code | residue | not a CA |
|---|---:|---:|
| `root.subject_key_identifier_extension_absent` | 102 | **102** |
| `root.basic_constraints_extension_absent` | 88 | **88** |
| `root.key_usage_extension_absent` | 101 | 63 |
| `root.extended_key_usage_extension_present` | 66 | 48 |

The first two are explained by this defect entirely; the other two carry a
real remainder of 38 and 18 certificates that is not this.

**Fix.** Test `is_ca` first, or require both: `if cert.is_self_issued and
cert.is_ca:`.
