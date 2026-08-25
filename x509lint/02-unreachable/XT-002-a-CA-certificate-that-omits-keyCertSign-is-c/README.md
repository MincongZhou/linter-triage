# XT-002 — a CA certificate that omits `keyCertSign` is checked as a leaf, and the check for that omission cannot fire

| | |
|---|---|
| **Tool** | `kroeckx/x509lint` at `103c92f` |
| **Group** | `02-unreachable` — Checks that cannot fire |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ |
| **Verified against** | zlint's own fixtures |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```
$ x509lint positive/XT-002-ca-without-keycertsign.pem     # CA:TRUE, ku = digitalSignature, keyEncipherment
E: No Subject alternative name extension
I: Checking as leaf certificate                  <- observed

$ x509lint positive/XT-002-ca-with-keycertsign.pem        # CA:TRUE, ku = ..., keyCertSign, cRLSign
I: Checking as intermediate CA certificate       <- correct for both
```

Both are zlint fixtures, both non-self-issued intermediates with critical
`basicConstraints` CA:TRUE. They differ in the keyUsage bits.

`GetType` derives the profile from `X509_check_ca` (`checks.c:1895`), and
OpenSSL's `check_ca` returns 0 whenever keyUsage is present and omits
`KU_KEY_CERT_SIGN` — tested before `basicConstraints` is consulted at all.
`XT-002-check-ca.c` executes that rather than asserting it: `bc.CA=TRUE`,
`keyCertSign=no`, `X509_check_ca=0`.

**This is not `XT-006`.** That entry also names `GetType`, but its subject is
a leaf certificate judged against the wrong *purpose* profile, and it says in
as many words that x509lint's axis is leaf / intermediate / root. Here the
axis itself is wrong: a CA certificate is placed on the leaf side of it.

Two consequences, and the second is why this is High.

**The leaf profile is applied.** `subjectAltName`, `certificatePolicies`,
`authorityInformationAccess`, revocation over HTTP, the 39-month ceiling and
the DV/OV subject rules are all demanded of a CA certificate. None of them
appears in the CA table at BR § 7.1.2.10.

**The subject of the check controls whether the check runs.** Omitting one
keyUsage bit from a CA certificate switches off x509lint's entire CA profile.

One check survives by accident: `ERR_BASIC_CONSTRAINTS_NO_CERT_SIGN_PATHLEN`
(`1672`) sits outside the type guard and fires 24 times here — but only where
the CA certificate carries a `pathLenConstraint`. A CA:TRUE with neither a
pathlen nor `keyCertSign` is reported by nothing.

Fix: type from `basicConstraints`, which is the field that says what the
certificate is, rather than from `X509_check_ca`, which answers whether it may
sign certificates:

```c
BASIC_CONSTRAINTS *bc = X509_get_ext_d2i(x509, NID_basic_constraints, NULL, NULL);
int ca = bc != NULL && bc->ca;
```

Keeping `X509_check_ca`'s tolerance of the pre-`basicConstraints` conventions is fine as a widening — `ca = (bc && bc->ca) || X509_check_ca(x509)` — never as the sole test.
