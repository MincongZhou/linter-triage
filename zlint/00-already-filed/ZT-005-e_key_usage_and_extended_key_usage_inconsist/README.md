# ZT-005 — `e_key_usage_and_extended_key_usage_inconsistent` reports certificates that have a consistent purpose

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `00-already-filed` — Already on your issue tracker |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | the lint's own two failing fixtures, plus a real certificate |
| **Would otherwise sit in** | see the adjudication below |

## Upstream issues, adjudicated

- **#553** — Revisiting `e_key_usage_and_extended_key_usage_inconsistent` lint and RFC interpretation. *(open)*
  **duplicate.** The same interpretation dispute, opened by a maintainer in 2021 and still open after 24 comments.
- **#593** — ISSUE: lint "e_key_usage_and_extended_key_usage_inconsistent" in technically constrained CA certificates *(open)*
  **related.** Same lint, technically constrained CA certificates. A 2024 comment claims resolution by #708; the issue is still open and this entry still reproduces.

## Analysis

Observed `error` on a certificate for which a purpose consistent with both
extensions exists; correct `pass`.

RFC 5280 §4.2.1.12 names one prohibited state:

> If a certificate contains both a key usage extension and an extended key
> usage extension, then both extensions MUST be processed independently and
> the certificate MUST only be used for a purpose consistent with both
> extensions. If there is no purpose consistent with both extensions, then the
> certificate MUST NOT be used for any purpose.

The lint's own `Description` restates it — "The certificate MUST only be used
for a purpose consistent with both key usage extension and extended key usage
extension." Its predicate asks a different question:

```go
var eku = map[x509.ExtKeyUsage]map[x509.KeyUsage]bool{
	x509.ExtKeyUsageServerAuth: {
		x509.KeyUsageDigitalSignature:                                true,
		x509.KeyUsageKeyEncipherment:                                 true,
		x509.KeyUsageKeyAgreement:                                    true,
		x509.KeyUsageDigitalSignature | x509.KeyUsageKeyEncipherment: true,
		x509.KeyUsageDigitalSignature | x509.KeyUsageKeyAgreement:    true,
	},
	...
}
...
if !eku[extKeyUsage][c.KeyUsage] { return &lint.LintResult{Status: lint.Error, ...} }
```

The inner map is keyed on the **whole** `keyUsage` bitmask, so the test is
membership of an enumerated combination rather than "is any asserted bit
consistent with a purpose the certificate carries". Asserting one further bit
alongside a consistent one is therefore an error, and §4.2.1.12 does not
prohibit it — the "Key usage bits that may be consistent" lines it draws on
are comments in the clause's ASN.1 and are permissive in form.

zlint's own fixtures for this lint demonstrate it, and differ by exactly one
bit:

| fixture | keyUsage | extKeyUsage | zlint |
|---|---|---|---|
| `kuEkuConsistent.pem` | digitalSignature | serverAuth | pass |
| `kuEkuInconsistent.pem` | digitalSignature, nonRepudiation | serverAuth | error |
| `kuEkuInconsistentMp.pem` | digitalSignature, dataEncipherment | emailProtection, clientAuth | error |

`digitalSignature` is on §4.2.1.12's list for `id-kp-serverAuth`, for
`id-kp-emailProtection` and for `id-kp-clientAuth`. All three certificates are
usable; the lint's own details line prints `DigitalSignature` while declaring
the certificate inconsistent.

A second reading inside the same table is isolated by the real certificate in
the reproduction, a certificate from Mozilla CA incident [bug
1262610](https://bugzilla.mozilla.org/show_bug.cgi?id=1262610). Its three bits
— digitalSignature, keyEncipherment, keyAgreement — are exactly the three RFC
5280 names for `id-kp-serverAuth`:

```
id-kp-serverAuth             OBJECT IDENTIFIER ::= { id-kp 1 }
-- TLS WWW server authentication
-- Key usage bits that may be consistent: digitalSignature,
-- keyEncipherment or keyAgreement
```

The table enumerates the pairs and not the triple, its comment reading the
"or" as exclusive: `(digitalSignature OR (keyEncipherment XOR keyAgreement))`.
That is arguable for `id-kp-emailProtection`, whose comment parenthesises
"(keyEncipherment or keyAgreement)" against an "and/or" earlier in the same
sentence; `id-kp-serverAuth` has no such parenthesis. It is recorded here
rather than separately because the fix below removes both.

```
299  dataEncipherment        16  keyEncipherment
130  nonRepudiation          10  cRLSign
 35  keyCertSign              1  keyAgreement
```

counted per certificate, so one carrying two surplus bits appears twice. The
other 6 assert only listed bits and fail on the exclusive reading alone. The
remaining 3 of the 403 are certificates with no consistent purpose at all,
which is the state the clause forbids and the only one this lint should
report.

Adjacent, and not numbered: two of the six, `crtsh6039677462` and
`crtsh6221458302` from bug1793692, carry a `keyUsage` BIT STRING declaring one
unused bit whose padding bit is set (`03 02 01 81`). zlint reports that
correctly under `e_incorrect_ku_encoding`, and under
`e_key_usage_incorrect_length` whose details read "the key usage... extension
is not parseable" — and this lint then computes a finding from the zero mask
zcrypto returned, printing "KeyUsage [] (00000000) inconsistent with
ExtKeyUsage ocspSigning". A finding derived from a value the same run declared
unparseable is a smaller problem than the one recorded here and has not been
isolated further.

Fix: key the table on a mask and test intersection rather than membership.

```go
var eku = map[x509.ExtKeyUsage]x509.KeyUsage{
	x509.ExtKeyUsageServerAuth: x509.KeyUsageDigitalSignature |
		x509.KeyUsageKeyEncipherment | x509.KeyUsageKeyAgreement,
	...
}
// union the masks of every tabulated purpose present, then
if c.KeyUsage&union == 0 { Error }
```

That is the state the clause and the lint's own `Description` name, and it
collapses `strictPurpose` and `multiPurpose` into one path. A `keyUsage` bit
no present purpose lists is a separate observation; if it is wanted it belongs
to a lint with a `w_` or `n_` prefix, since the clause does not forbid it and
reporting it at error condemns certificates that break nothing.
