# ZT-003 — `e_subject_dn_not_printable_characters` reads a BMPString's padding as U+0000

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `00-already-filed` — Already on your issue tracker |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | zlint's own fixtures |
| **Would otherwise sit in** | see the adjudication below |

## Upstream issues, adjudicated

- **#818** — Printable `BMPString` in subject DN fields marked as failing lint `e_subject_dn_not_printable_characters` *(open)*
  **duplicate.** Same claim. #818 carries a linked PR that is not merged. Upstream tracks as one issue what this document splits into ZT-003 and ZT-007.

## Analysis

Observed `error` on a subject whose only unusual feature is a wide string
type; correct `pass`.

```go
bytes := attrTypeAndValue.Value.Bytes
for len(bytes) > 0 {
    r, size := utf8.DecodeRune(bytes)
    if r < 0x20 {
        return &lint.LintResult{Status: lint.Error}
    }
```

`Value.Bytes` is the content octets of the attribute value, whatever string
type carried it. BMPString writes every code point in two octets and
UniversalString in four, so any character below U+0100 — every ASCII letter —
carries a leading `0x00`. `utf8.DecodeRune` reads that octet as U+0000.
Executed against the content octets of `"US"` as a BMPString:

```
00 55 00 53
rune=U+0000 size=1  ->  lint sees control: true
rune=U+0055 size=1  ->  lint sees control: false
```

or UniversalString subject attribute; all thirteen have a `0x00` among the
content octets, all thirteen are faulted, and none holds a control character.
Eight are zlint's own testdata for `e_subject_rdns_correct_encoding`, whose
whole purpose is to carry an attribute in a string type the BR table forbids —
their subject values are the ASCII strings `"BMPString"` and `"U"`. The
remaining twelve firings are narrow-string attributes that really do hold a
control character, eleven subscriber certificates from CA incident bugs and
one trust-store root. So 52 percent of this lint's findings are wrong, and the
sibling that owns those certificates reports them correctly.

Fix: decode by tag before scanning. `util.ParseBMPString` already exists and
the lint file next door calls it for exactly this reason; UniversalString
needs a four-octet equivalent.
