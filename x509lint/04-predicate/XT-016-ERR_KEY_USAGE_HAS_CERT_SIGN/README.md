# XT-016 — the certificate type is inferred from state a defect can change

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

Found by the integrator on 2026-08-23 while checking this lane's claim that
`ERR_KEY_USAGE_HAS_CERT_SIGN` and
`rfc5280/e_ext_key_usage_cert_sign_without_ca` are an exact 1:1 match at 66
certificates each. The totals are equal.

### This is a third path into `XT-002`'s territory, not a duplicate of it

`XT-002` already establishes that `GetType` derives the profile from
`X509_check_ca` and that OpenSSL's `check_ca` returns 0 whenever `keyUsage` is
present and omits `KU_KEY_CERT_SIGN` — **tested before `basicConstraints` is
consulted at all**. Its subject is a CA certificate that omits `keyCertSign`.

### The mechanism

`GetType` (`checks.c:1893`) decides the certificate's profile from
`X509_check_ca(x509)` and returns `SubscriberCertificate` when it is zero. The
site itself (`checks.c:1517`) is conditional on that profile:

```c
if (type == SubscriberCertificate && (bits & KU_KEY_CERT_SIGN) != 0)
{
    SetError(ERR_KEY_USAGE_HAS_CERT_SIGN);
}
```

So the check runs only on certificates OpenSSL declines to call CAs, and
`X509_check_ca` answers from the cached extension flags rather than from the
`basicConstraints` extension alone. That makes the profile **derived from
parsed state that any defect in the certificate can change**, and it goes
wrong in both directions at once.

### Observed, both directions

Seventeen of the eighteen carry **no `basicConstraints` extension at all**, so
RFC 5280 § 4.2.1.9's own default makes them `cA: FALSE`; `X509_check_ca`'s
legacy heuristics call them CAs on the strength of `keyCertSign` being set,
which is the very bit whose presence without `cA` is the violation.
`ec_strict_cert_sign_ku.pem` and its ten siblings are the population.

All eighteen carry `CA:TRUE`, and **all eighteen are labelled `I: Checking as
leaf certificate` by x509lint's own output**, eleven of them beside `E: Error
parsing certificate`. A defect elsewhere in the certificate clears the
extension cache, the certificate is re-profiled as a subscriber, and it is
then reported for a bit a CA is entitled to set. `caMaxPathNegative.pem`
prints all three lines together and is the shortest demonstration:

```
E: Key usage has keyCertSign
E: Basic Constraints with negative length
I: Checking as leaf certificate
```

The negative `pathLenConstraint` is the real defect; the `keyCertSign` report
is collateral, and a reader is told a conforming field is wrong.

### Why High

The subject of the check can change whether the check applies to it. This is
the same class as a date gate reading `notBefore` for a rule about backdating
— recorded in `.claude/skills/x509-lint-authoring/SKILL.md` § 9 — and it is
worse here, because it moves in both directions: one defect suppresses the
check, another summons it.

Both columns were measured here.

### The fix

Decide the profile from `basicConstraints` as RFC 5280 § 4.2.1.9 defines it,
with its stated default when the extension is absent, rather than from
`X509_check_ca`'s compatibility heuristics — and do not let a parse failure
elsewhere change the answer.

**Lane `x5-j` executed it and that is wrong.** `EXFLAG_CA` is cached correctly
on the demoted certificates — on all of them.

The mechanism is `X509_check_ca`'s own first line:

```c
if (!ossl_x509v3_cache_extensions(x))
    return 0;
```

which returns `(ex_flags & EXFLAG_INVALID) == 0`. So **any** extension
anywhere in the certificate that sets `EXFLAG_INVALID` demotes a CA to a leaf
— it need not be `basicConstraints` and need not be related to CA-ness at all.
`x5-j` demonstrated it with a one-octet pair differing only in a `GeneralName`
tag inside `nameConstraints`: the control reads `I: Checking as root CA
certificate` and draws one true finding; its twin loses that line and gains
**eight spurious errors and two spurious warnings**, one of them `E: Key usage
has keyCertSign` — the bit BR § 7.1.2.10.7 *requires* of a CA.

It also breaks `self_issued`, because `X509_check_issued` fails under the same
guard, producing a spurious `ERR_AKID_MISSING` on a self-signed root.

The hypothesis was reasonable and it was still a hypothesis, labelled as one
here, and reading would never have settled it. `XT-002` settled its own route
by compiling C; this one needed the same and now has it. See
[`x509lint-lane-x5-j.md`](x509lint-lane-x5-j.md).
