# CT-007 — a conforming version 1 certificate is reported as an error

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | two real, unmodified certificates |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

### The code

```ruby
    if cert.version > 2
      messages << 'E: Invalid certificate version'
    elsif cert.version < 2
      messages << 'E: Old certificate version (not X.509v3)'
    end
```

### The mechanism

The `elsif` branch reports every certificate that is not version 3. certlint's
own README defines `E:` as "issues where the certificate is not compliant with
the standard", and `certlint.rb` is the RFC 5280 layer — `bin/cablint` is
where the CA/Browser Forum's requirements are added. RFC 5280 §4.1.2.1 states:

> If only basic fields are present, the version SHOULD be 1 (the value is
> omitted from the certificate as the default value); however, the version MAY
> be 2 or 3.

A version 1 certificate carrying only basic fields is the form the clause
recommends. Nothing in RFC 5280 makes it an error, and there is no citation at
the emission site.

The requirement that a certificate be version 3 is CA/Browser Forum BR §7.1.1,
effective 2015-04-16 and scoped to TLS server certificates. Applying it
unconditionally at the RFC layer also applies it to S/MIME, code-signing and
time-stamping certificates that `bin/cablint` deliberately never judges.

### Reproduction

`CL-T-cl-h-02-v1-trust-store-root.der` is a CCADB-included root CA,
unmodified:

```
$ ruby -I lib -I ext bin/certlint CL-T-cl-h-02-v1-trust-store-root.der
E: Old certificate version (not X.509v3)

$ ruby -I lib -I ext bin/certlint CL-T-cl-h-02-control-v3-subscriber.der
I: Certificate Transparency Precertificate identified
```

**observed** — an error on a certificate whose only unusual property is that
it is version 1. **correct** — nothing.

The sibling branch is sound and this report does not touch it: a version above
3 is genuinely outside the profile, since RFC 5280 §4.1 gives `Version` the
named numbers v1(0), v2(1) and v3(2) and §4.1.2.1 reaches no fourth. Two
fabricated certificates confirm the branch fires there, at encoded version 3
and at a five-octet version.

### Fix

Move the `elsif` branch to `bin/cablint`, or gate it on the certificate
asserting a CA/Browser Forum policy identifier or `id-kp-serverAuth`. If it
stays in `certlint.rb`, `W:` matches what RFC 5280 actually says, since
§4.1.2.1 uses SHOULD.
