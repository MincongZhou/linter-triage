# PT-003 — a withdrawn requirement and its replacement are both applied to every certificate

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ |
| **Verified against** | a real 2015 Swisscom certificate |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

`pkilint/pkix/certificate/certificate_extension.py:485`, in
`CertificatePoliciesUserNoticeValidator.validate`:

```python
if encoding not in ["ia5String", "utf8String"]:
    -> pkix.rfc5280_certificate_policies_invalid_explicit_text_encoding
if encoding not in ["bmpString", "utf8String", "visibleString"]:
    -> pkix.rfc6818_certificate_policies_invalid_explicit_text_encoding
```

Both tests run on every certificate. Neither consults `notBefore`, and the
validator takes no `validity_period_start_retriever`.

**The two documents do not layer — the second replaces the first.**

> Conforming CAs SHOULD use the UTF8String encoding for explicitText, but MAY
> use IA5String. **Conforming CAs MUST NOT encode explicitText as VisibleString
> or BMPString.**

RFC 6818 § 3, January 2013, under the heading *"This paragraph is replaced
with"*:

> Conforming CAs SHOULD use the UTF8String encoding for explicitText.
> **VisibleString or BMPString are acceptable but less preferred
> alternatives.** Conforming CAs MUST NOT encode explicitText as IA5String.

From 2013-01-01 the two encodings the `rfc5280` code reports are acceptable,
and the one it permits is prohibited. Applying both unconditionally means
every certificate carrying an explicitText is judged against a rule that was
withdrawn, a rule that did not yet exist, or both.

explicitText and draw the `rfc5280` code. **780 were issued on or after
2013-01-01**, when RFC 6818 had already made the encoding acceptable —
measured by reading `notBefore` on all 851, not sampled. The remaining 71
predate RFC 5280's own publication and are outside any version of the
requirement.

The encodings were confirmed by decoding, not assumed: across 80 of the
reported certificates, 37 carry a `visibleString` and 43 a `bmpString`, and
none carries anything else.

**Fix.** Gate each code on `notBefore` against 2013-01-01 — the `rfc5280` test
below it, the `rfc6818` test from it.
