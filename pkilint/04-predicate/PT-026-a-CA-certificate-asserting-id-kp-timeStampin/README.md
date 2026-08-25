# PT-026 — a CA certificate asserting `id-kp-timeStamping` is reported as carrying an

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | reproduced on a corpus certificate with the shipped CLI |

## Upstream issues, adjudicated

- **#114** — Check Certificate Policies in S/MIME intermediates *(open)*
  **related.** An open request to check certificate policies in S/MIME intermediates. Adjacent population, different claim.

## Analysis

unknown purpose, not a prohibited one**

### The clause

`Policies/Cert-BR-Baseline.md` § 7.1.2.10.6, *CA Certificate Extended Key
Usage*, tabulates eight purposes. Six are **MUST NOT**, and
`id-kp-timeStamping` (1.3.6.1.5.5.7.3.8) is one of them:

| Key Purpose | OID | Presence |
|---|---|---|
| `id-kp-codeSigning` | 1.3.6.1.5.5.7.3.3 | MUST NOT |
| `id-kp-emailProtection` | 1.3.6.1.5.5.7.3.4 | MUST NOT |
| **`id-kp-timeStamping`** | **1.3.6.1.5.5.7.3.8** | **MUST NOT** |
| `id-kp-OCSPSigning` | 1.3.6.1.5.5.7.3.9 | MUST NOT |
| `anyExtendedKeyUsage` | 2.5.29.37.0 | MUST NOT |
| Precertificate Signing Certificate | 1.3.6.1.4.1.11129.2.4.4 | MUST NOT |
| Any other value | — | NOT RECOMMENDED |

### The predicate

`pkilint/cabf/serverauth/serverauth_ca.py`,
`TlsCaCertificateAllowedEkuValidator`, whose own docstring reads "Validates
that the content of the extended key usage extension complies with BR
7.1.2.10.6":

```python
_EKU_ALLOWANCES = {
    **{
        e: Rfc2119Word.MUST_NOT
        for e in (
            rfc5280.id_kp_codeSigning,
            rfc5280.id_kp_emailProtection,
            rfc5280.id_kp_OCSPSigning,
            rfc5280.anyExtendedKeyUsage,
            rfc6962.id_kp_precertificateSigning,
        )
    },
    rfc5280.id_kp_serverAuth: Rfc2119Word.MUST,
    rfc5280.id_kp_clientAuth: Rfc2119Word.MAY,
}

def __init__(self):
    super().__init__(
        self._EKU_ALLOWANCES, self._CODE_CLASSIFIER, Rfc2119Word.SHOULD_NOT
    )
```

Five MUST_NOTs, not six. `rfc5280.id_kp_timeStamping` is absent, so the
purpose falls to the constructor's third argument — the default for anything
the table does not name, `Rfc2119Word.SHOULD_NOT` — and the base class emits
`cabf.serverauth.ca.unknown_eku_present` at **WARNING**. The code the class
would emit for a tabulated prohibition,
`cabf.serverauth.ca.timestamping_eku_present`, is not in the catalogue at all:

```
$ python - <<'PY'   # abridged; the full walk is in the lane's manifest
from pkilint.cabf.serverauth import serverauth_ca
v = serverauth_ca.TlsCaCertificateAllowedEkuValidator()
print(sorted(f.code for f in v.validations if 'eku' in f.code))
PY
['cabf.serverauth.ca.anyeku_eku_present',
 'cabf.serverauth.ca.codesigning_eku_present',
 'cabf.serverauth.ca.emailprotection_eku_present',
 'cabf.serverauth.ca.ocspsigning_eku_present',
 'cabf.serverauth.ca.precertsigning_eku_present',
 'cabf.serverauth.ca.serverauth_eku_absent',
 'cabf.serverauth.ca.unknown_eku_present']
```

### Why this is a slip and not a design

Its two siblings, written to the same base class and against the neighbouring
tables, both list the purpose:

- `serverauth_cross_ca.py`, `CrossCertificateAllowedEkuValidator`: `rfc5280.id_kp_timeStamping: Rfc2119Word.MUST_NOT` — BR § 7.1.2.2.5. - `serverauth_subscriber.py`, `SubscriberEkuAllowanceValidator`: `rfc5280.id_kp_timeStamping: Rfc2119Word.MUST_NOT` — BR § 7.1.2.7.10.

§ 7.1.2.7.10 and § 7.1.2.10.6 list the same eight rows and differ only in what
they require of `id-kp-serverAuth`. The subscriber validator has all six
prohibitions and the CA validator has five.

`NonTlsCaCertificateAllowedEkuValidator` in the same file omits the purpose
deliberately and correctly — BR § 7.1.2.3.3 gives "Any other value" as **MAY**
for a Non-TLS CA — which is the control showing the omission is meaningful
where the table says MUST NOT.

### Reproduction

```
$ lint_cabf_serverauth_cert lint -d -o -s WARNING \
        # PEM-armoured
INTERNAL_CONSTRAINED_TLS_CA
TlsCaCertificateAllowedEkuValidator @ …extKeyUsageSyntax
    cabf.serverauth.ca.codesigning_eku_present (ERROR)
    cabf.serverauth.ca.emailprotection_eku_present (ERROR)
    cabf.serverauth.ca.ocspsigning_eku_present (ERROR)
    …
    cabf.serverauth.ca.unknown_eku_present (WARNING): Unknown EKU present: 1.3.6.1.5.5.7.3.8
```

`1.3.6.1.5.5.7.3.8` is `id-kp-timeStamping`, reported as unknown on a
certificate pkilint has itself typed `INTERNAL_CONSTRAINED_TLS_CA`.

### Reach

28 of the certificates: those on which
`cabf.serverauth.ca.unknown_eku_present` fires (133) and whose
`extendedKeyUsage` carries 1.3.6.1.5.5.7.3.8, read independently through
`cryptography` 50.0.0 — 12 `INTERNAL_CONSTRAINED_TLS_CA` and 16
`INTERNAL_UNCONSTRAINED_TLS_CA`. Every one is a CA certificate that BR §
7.1.2.10.6 says MUST NOT carry the purpose and that pkilint reports below the
error floor, so a consumer running pkilint at its default severity sees
nothing.

`e_ca_eku_prohibited` reads `spec::eku::SUBSCRIBER_TABLE`'s `ca` column, which
carries `Presence::Prohibited` for `id-kp-timeStamping`, and a workspace test
(`the_two_profiles_agree_on_every_prohibition`) fails if the two columns ever
diverge on a prohibition. The rule's own positive fixture is
`synthetic-subca-eku-timestamping.pem`.

### Suggested fix
