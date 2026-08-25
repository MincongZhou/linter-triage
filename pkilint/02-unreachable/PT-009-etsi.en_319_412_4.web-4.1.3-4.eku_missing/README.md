# PT-009 — `web-4.1.3-4.eku_missing` is installed only where its own predicate cannot hold

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `02-unreachable` — Checks that cannot fire |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

`en_319_412_4.NcpWExtendedKeyUsagePresenceValidator` reports an absent
`extendedKeyUsage`. `etsi/__init__.py:344` installs it only when

```python
certificate_type not in etsi_constants.CABF_CERTIFICATE_TYPES
    and certificate_type in etsi_constants.WEB_AUTHENTICATION_CERTIFICATE_TYPES
```

which is `NON_CABF_WEB_AUTHENTICATION_CERTIFICATE_TYPES` — the `NCP_W_*` and
`QNCP_W_GEN_*` members. `determine_certificate_type` returns one of those only
from inside an `if is_webauth:` branch, and

```python
is_webauth = rfc5280.id_kp_serverAuth in cert.extended_key_usages
```

A certificate with no `extendedKeyUsage` has no `id-kp-serverAuth`, so it is
never given a type this validator is installed on. This is the shape
`gen-5.1.1.qc_eu_pds_missing` has in the reproduction beside this file: a
check installed only where its own predicate is the negation of the
installation condition.

**Not the same as PT-008.** The `-t` option forces a type, and under `-t
NCP-W-LEGAL-PERSON-FINAL-CERTIFICATE` the check does fire. It is unreachable
on the detection path, which is the one the tool's own help text recommends
and the one every automated caller uses.

### Reproduction

Two certificates differing only in whether `extendedKeyUsage` is present:

```
$ lint_etsi_cert lint -d -o -r /tmp/with-eku.pem
NCP-W-LEGAL-PERSON-FINAL-CERTIFICATE
$ lint_etsi_cert lint -d -o -r /tmp/without-eku.pem
NCP-LEGAL-PERSON-CERTIFICATE
```

**observed** — removing the extension moves the certificate out of the profile
that polices the extension. **correct** — a certificate the CA intended as a
website certificate and issued without an `extendedKeyUsage` is exactly what
WEB-4.1.3-4 a) forbids, and is the certificate that ends up unjudged.

### Fix

The same class of fix as PT-008: decide the ETSI certificate type from
something the check does not police. WEB-4.1.3-1 defines an NCP-w certificate
by its *certificate policy*, not by its key purposes, so
`determine_certificate_type` reading `id-etsi-qct-web` or the EN 319 411-1 NCP
identifier for the `is_webauth` limb would leave `eku_missing` reachable.

### Severity

**Medium**: pkilint fails to report a real requirement over a bounded
population — website certificates issued with no `extendedKeyUsage` — rather
than reporting unverified conformance across the board. It is a step milder
than PT-008 only because `-t` still reaches it.
