# ZT-086 — `w_ext_cert_policy_explicit_text_includes_control` only reads the `UTF8String` arm, so a CA evades it by choosing any other encoding

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | reproduced against real certificates, not fabricated material |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

The check's own citation states the requirement without naming an encoding:

> The explicitText string SHOULD NOT include any control characters (e.g.,
> U+0000 to U+001F and U+007F to U+009F).

(RFC 5280 §4.2.1.4, `Specs/rfc/rfc5280.txt` line 1822 — see ZT-071 for why
this sentence is RFC 5280's, not RFC 6818's as the check's `Citation` field
claims.) But `Execute` only walks the text when the arm is `UTF8String`:

```go
if text.Tag == 12 {
    for i := 0; i < len(text.Bytes); i++ {
        ...
```

The other three `DisplayText` arms — `ia5String`, `visibleString`, `bmpString`
— are never inspected. Nothing in the cited sentence conditions it on
encoding, unlike the NFC sentence two lines later in the same paragraph, which
explicitly says "When the UTF8String encoding is used."

```
$ zlint -format der -includeNames w_ext_cert_policy_explicit_text_includes_control \
    
{"w_ext_cert_policy_explicit_text_includes_control":{"result":"pass"}}
```

**correct**: `warn`. The explicitText string plainly contains C0 control
characters; the arm it happens to be encoded in is not part of the cited
sentence's condition.

**fix**: read `text.Bytes` for every `DisplayText` arm the qualifier's
`explicitText` uses, not only tag 12. The four arms differ in how a byte
sequence maps to characters (`IA5String`/`VisibleString` one octet per
character, `BMPString` two-octet UCS-2BE code units, `UTF8String` variable-
width UTF-8) so the walk needs a per-arm decode, not a single byte loop reused
across all four.
