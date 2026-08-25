# ZT-087 — `w_ext_cert_policy_explicit_text_includes_control` and `w_ext_cert_policy_explicit_text_not_utf8` are dated five years later than their own cited text

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

Both checks carry `Citation: "RFC 6818: 3"` and `EffectiveDate:
util.RFC6818Date` (2013-01-01). Reading RFC 5280 and RFC 6818 side by side
(`Specs/rfc/rfc5280.txt` lines 1817-1823, `Specs/rfc/rfc6818.txt` lines
159-190) shows RFC 6818 §3 replaces the whole tenth paragraph of RFC 5280
§4.2.1.4, but two of its sentences are **carried over verbatim**, not amended:

- the control-character sentence ZT-086 quotes above, and - "Conforming CAs SHOULD use the UTF8String encoding for explicitText" — the opening clause `w_ext_cert_policy_explicit_text_not_utf8` answers, present word-for-word in RFC 5280 (2008) and repeated unchanged as the opening of RFC 6818's replacement paragraph (2013).

Both requirements were therefore already in force under RFC 5280 in May 2008.
What RFC 6818 changed in the same paragraph — the status of `IA5String` (MAY →
MUST NOT) and of `VisibleString`/`BMPString` (MUST NOT → acceptable but less
preferred) — is unrelated to either of these two sentences.

**observed**: dated `2013-01-01`, so a certificate issued 2008-05-01 through
2012-12-31 carrying a control character in `explicitText`, or not using
`UTF8String` for it, draws `NE` rather than `warn`.

```
$ zlint -format der -includeNames w_ext_cert_policy_explicit_text_not_utf8 \
    
{"w_ext_cert_policy_explicit_text_not_utf8":{"result":"NE"}}
```

**correct**: `warn` from 2008-05-01, not 2013-01-01, for both checks.

Two of the paragraph's five sentences are new in 2013 (the
`IA5String`/`VisibleString`/ `BMPString` status flip, and the NFC sentence's
extension to `BMPString` — see ZT-071); the other two, including both of these
checks' own basis, are not.

**fix**: date both checks `util.RFC5280Date` (2008-05-01).
