# ZT-063 — `e_subscribers_crl_distribution_points_are_http` reports an extension that is absent

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `08-hygiene` — Descriptions, citations, severities and tests |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | zlint's own fixtures, unmodified |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```go
Description: "cRLDistributionPoints SHALL have URI scheme HTTP."
Citation:    7.1.2.3.b
```

The two branches of `Execute` are written differently and only one guards
against an empty list:

```go
if (IsMultipurposeSMIMECertificate(c) || IsStrictSMIMECertificate(c)) &&
        httpCount != len(c.CRLDistributionPoints) { ... }   // vacuous when empty
if IsLegacySMIMECertificate(c) && httpCount == 0 { ... }    // fires when empty
```

A Legacy S/MIME certificate carrying no `cRLDistributionPoints` at all draws
an error from a lint about the URI scheme, with the details *"SMIME
certificate contains no HTTP URI schemes as CRL distribution points"* — a
sentence about a certificate that has distribution points, which this one does
not.

`e_subscribers_shall_have_crl_distribution_points` already reports it, with
the right message. So one missing extension is two findings whose repair is
the same edit, and the second misdescribes what is wrong.

**Low, not Medium.** The certificate is reported either way, so no verdict
changes; the harm is a reader counting two defects where there is one, and
being told about a scheme on an extension that is not there.

Fix: guard the Legacy branch the way its sibling already is —
`len(c.CRLDistributionPoints) > 0 && httpCount == 0`.

**Two branches of one function, one guarded and one not.** The reporting
skill's test is that two of anything is a design and one is a slip; here the
two branches are the pair, and they disagree.
