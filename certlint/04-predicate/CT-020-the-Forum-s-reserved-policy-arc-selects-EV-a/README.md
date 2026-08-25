# CT-020 — the Forum's reserved policy arc selects EV and never excludes

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | fabricated one-field pair, real corpus evidence |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```
$ cablint positive/CT-020-smime-policy-no-eku.pem   # policy 2.23.140.1.5.1.2, rfc822Name SAN, no EKU
I: TLS Server certificate identified
E: BR certificates must be 398 days in validity or less
E: BR certificates must include authorityInformationAccess
E: Unless Short-lived, BR certificates must include the HTTP URL of at least one OCSP responder or CRL Distribution Point
E: BR certificates must not contain rfc822Name type alternative name
E: commonNames in BR certificates must be from SAN entries
```

Add an `emailProtection` `extendedKeyUsage` and cablint says `I: No
certificate type identified`. The two certificates differ in that one
extension; the policy identifier is identical in both and is not what decides
the answer.

**cablint does read the reserved arc — sixty lines earlier, and only to
select.**

```
cablint.rb:359   if certpolicies.value.include?('2.23.140.1.')     # the arc
cablint.rb:360     if ...('2.23.140.1.1') || ...('2.23.140.1.3')   # EV TLS, EV CS
                     is_ev = true
...
cablint.rb:408   if eku.empty? && !ku.nil?
cablint.rb:410     if ku.include?('Digital Signature') || ku.include?('Key Encipherment')
cablint.rb:411       eku << 'tmp-serverauth-usable'
cablint.rb:428   # "So many ways to indicate an in-scope certificate"
```

`digitalSignature` + `keyEncipherment` is the ordinary shape of an S/MIME
signing and encryption certificate, so the keyUsage inference fires on exactly
the population it should not — and the value that would stop it was parsed
three lines from where the type is decided.

The comment above line 422 states the reasoning honestly: *"If the certificate
has neither keyUsage nor extendedKeyUsage, it is unrestricted so it can be
used for anything, including server authentication."* That is true of RFC 5280
and not of a certificate whose CA has asserted `2.23.140.1.5.x`, which is the
Forum's own identifier for "the S/MIME Baseline Requirements govern this".

```
61  S/MIME arc, no extendedKeyUsage        typed from keyUsage alone
 2  Code Signing arc, no extendedKeyUsage  the same
 2  S/MIME arc, EKU names serverAuth       correctly typed — asserting
                                           serverAuth puts it in scope
```

The 63 draw, among others, 63 × `must include authorityInformationAccess`, 63
× `must have subject alternative names extension`, 52 × `must be 398 days in
validity or less` and 17 × `commonNames must be from SAN entries`. Every
certificate with an `emailProtection` EKU is correctly left alone, which is
why the figure is 61 and not 391: the defect needs the EKU to be absent.

Fix: let the arc exclude as well as select. A certificate asserting
`2.23.140.1.5.x` or `2.23.140.1.4.x`, and not also asserting `serverAuth`, is
not a TLS server certificate whatever its `keyUsage` says.

**Distinct from the § 1.1 scope divergence** recorded in
[SPEC-NOTES.md](../SPEC-NOTES.md), which is a reading neither tool is wrong
about. This one is not a reading: the Forum assigned that arc to a different
document, and cablint parses it and then does not use it.
