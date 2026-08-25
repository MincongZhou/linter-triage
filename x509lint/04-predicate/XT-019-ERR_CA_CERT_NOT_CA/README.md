# XT-019 — `ERR_CA_CERT_NOT_CA` has no reachable input

| | |
|---|---|
| **Tool** | `kroeckx/x509lint` at `103c92f` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

### The code

```c
static void CheckBasicConstraints(X509 *x509, CertType type)
{
    BASIC_CONSTRAINTS *bc = X509_get_ext_d2i(x509, NID_basic_constraints, &critical, NULL);
    if (bc == NULL) { ... return; }
    if (type != SubscriberCertificate)
    {
        if (critical == 0)
            SetError(ERR_BASIC_CONSTRAINTS_NOT_CRITICAL);
        if (bc->ca == 0)
        {
            /* X509_check_ca() supports various old methods to detect a CA. */
            SetError(ERR_CA_CERT_NOT_CA);
        }
    }
```

The comment states the intent exactly, and it is a good check to want:
*OpenSSL calls this a CA by one of its legacy routes, and `basicConstraints`
says `cA:FALSE`.*

### Why it cannot fire

Reaching `checks.c:1657` needs three things at once:

1. `basicConstraints` present and parseable — otherwise line 1639 or 1644
returned; 2. `bc->ca == 0`; 3. `X509_check_ca(x509) != 0`, which is what makes
`type != SubscriberCertificate`.

OpenSSL's `check_ca` consults its legacy routes only in the `else` arm of `if
(x->ex_flags & EXFLAG_BCONS)`. Condition (1) sets `EXFLAG_BCONS`; condition
(2) leaves `EXFLAG_CA` clear; so `check_ca` returns 0 from the `BCONS` branch
and never reaches `V1_ROOT`, `EXFLAG_KUSAGE` or `EXFLAG_NSCERT`. Condition (3)
is therefore false whenever (1) and (2) hold.

### Executed, not read

Three fabricated certificates, one per legacy route, each carrying an explicit
critical `basicConstraints` `cA:FALSE`:

```
./exflags XL-T-x5-j-02-ca-false-*.pem

  both          bc.CA=false keyCertSign=yes X509_check_ca()=0  BCONS=1 EXFLAG_CA=0
  keycertsign   bc.CA=false keyCertSign=yes X509_check_ca()=0  BCONS=1 EXFLAG_CA=0
  nscerttype    bc.CA=false keyCertSign=no  X509_check_ca()=0  BCONS=1 EXFLAG_CA=0
```

All three draw `I: Checking as leaf certificate` from x509lint and none draws
`E: CA certificate with CA:false`.

### Why Medium

Nothing is reported falsely and no verdict flips; a check that exists and
answers nothing is a gap rather than a wrong answer. It is Medium rather than
Low because the population it was written for is not empty — `XT-002`'s and
`XT-020`'s 83 mistyped CA certificates are the same axis failing the other
way, and a working `ERR_CA_CERT_NOT_CA` is one of the checks that would catch
a CA certificate lying about its own `cA` bit.

This is `XT-002`'s second consequence on a second check. There the unreachable
one was `WARN_KEY_USAGE_NO_CERT_OR_CRL_SIGN`; here it is `ERR_CA_CERT_NOT_CA`.
Both sit inside the same `type != SubscriberCertificate` guard, and in both
cases the defect the check exists to report is part of what switches the guard
off.

### Fix

`XT-002`'s. Type from `basicConstraints`, keeping `X509_check_ca` only as a widening: `ca = (bc && bc->ca) || X509_check_ca(x509)`. Under that reading a `cA:FALSE` certificate carrying a legacy CA signal is typed a CA and line 1657 fires, which is what it was written for.

### How this lane handled it
