# PT-001 — RFC 6818 replaced RFC 5280's `explicitText` rule with its opposite, and both run

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool |
| **Cases** | positive/ |
| **Verified against** | `pkilint./repro.sh` (all four `DisplayText` alternatives, identical certificates otherwise) |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

> Conforming CAs SHOULD use the UTF8String encoding for explicitText, but MAY
> use IA5String. Conforming CAs MUST NOT encode explicitText as VisibleString
> or BMPString.

RFC 6818 §3, January 2013, under the heading *"This paragraph is replaced
with"*:

> Conforming CAs SHOULD use the UTF8String encoding for explicitText.
> VisibleString or BMPString are acceptable but less preferred alternatives.
> Conforming CAs MUST NOT encode explicitText as IA5String.

**Replaced, not added alongside**, and the two prohibitions are exact
complements. `CertificatePoliciesUserNoticeValidator.validate` implements
both, at ERROR, unconditionally:

```python
if encoding not in ["ia5String", "utf8String"]:
    ... VALIDATION_EXPLICITTEXT_INVALID_ENCODING_5280       # ERROR
if encoding not in ["bmpString", "utf8String", "visibleString"]:
    ... VALIDATION_EXPLICITTEXT_INVALID_ENCODING_6818       # ERROR
```

The intersection of the two allow-lists is `{utf8String}`. `DisplayText` has
exactly four alternatives, so three of the four are an error whatever the
certificate's date:

```
positive/PT-001-utf8string.pem      (nothing)
positive/PT-001-ia5string.pem       pkix.rfc6818_certificate_policies_invalid_explicit_text_encoding
positive/PT-001-visiblestring.pem   pkix.rfc5280_certificate_policies_invalid_explicit_text_encoding
positive/PT-001-bmpstring.pem       pkix.rfc5280_certificate_policies_invalid_explicit_text_encoding
```

All four fixtures are issued **2025-01-01**, twelve years after the
replacement.

**observed** — a certificates whose `explicitText` is a `VisibleString` is
reported at ERROR, and the governing text calls that encoding "acceptable".

**correct** — date the two findings against `notBefore`, or drop the
superseded one. At most one of them can be right about any certificate, and
which one depends on when it was issued. Running both makes `utf8String` the
only encoding pkilint accepts, which is neither document's rule.

*The 780 was 781 when this was first written.

**Why Medium and not High.** Nothing is suppressed and no other check is taken
down; the defect is a false positive at the error floor. It earns more than
Low because the verdict changes — a conforming certificate is reported as an
error — and because pkilint's output is consumed as ground truth by others.

This is different in kind: the two findings contradict *each other*, both are
declared ERROR, and the tool ships the superseded rule and its replacement
side by side with nothing to choose between them.
