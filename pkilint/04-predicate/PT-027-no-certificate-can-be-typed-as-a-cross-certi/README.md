# PT-027 — no certificate can be typed as a cross-certified subordinate CA under

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | 18 distinct codes catalogued at 19 severity slots, some reachable |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

`--detect`, so eighteen catalogued codes are unreachable**

**Confirmed** · **Low** · 18 distinct codes catalogued at 19 severity slots,
some reachable

`serverauth_cross_ca.py` declares `_CODE_CLASSIFIER =
"cabf.serverauth.cross_ca"` and two validators over BR § 7.1.2.2.3, §
7.1.2.2.4 and § 7.1.2.2.5. Walking every validator container the serverauth
profile builds, for every `CertificateType` it declares, the pair generates
eighteen distinct codes over nineteen severity slots
(`extended_key_usage_extension_absent` is ERROR for the external cross-CA
types and WARNING for the internal ones).

None of them can fire under `--detect`. `pkilint/cabf/serverauth/__init__.py`:

```python
def determine_certificate_type(cert):
    if cert.is_self_issued:
        return serverauth_constants.CertificateType.ROOT_CA
    if cert.is_ca:
        return _determine_intermediate_ca_type(cert)
    ...

def _determine_intermediate_ca_type(cert):
    ekus = cert.extended_key_usages
    if not ekus:
        ekus = {rfc5280.id_kp_serverAuth}
    if rfc6962.id_kp_precertificateSigning in ekus:
        return ...PRECERT_SIGNING_CA
    elif rfc5280.id_kp_serverAuth in ekus or rfc5280.anyExtendedKeyUsage in ekus:
        ... INTERNAL_CONSTRAINED_TLS_CA / INTERNAL_UNCONSTRAINED_TLS_CA
    else:
        return ...NON_TLS_CA
```

The function's whole codomain for a CA certificate is `ROOT_CA`,
`PRECERT_SIGNING_CA`, `INTERNAL_CONSTRAINED_TLS_CA`,
`INTERNAL_UNCONSTRAINED_TLS_CA` and `NON_TLS_CA`. The eight `*CROSS_CA` and
`EXTERNAL_*` members of `CertificateType` are reachable only through `-t`.

This is not obviously a bug — a cross certificate is not identifiable from a
single certificate, so `--detect` cannot classify one, and pkimetal and this
project both drive pkilint with `--detect`. It is recorded because the codes
count toward pkilint's catalogue and toward any coverage denominator built
from it, while no `--detect` consumer can ever exercise them. Anyone reading
"pkilint has N validations" should know that eighteen of them need `-t`.
