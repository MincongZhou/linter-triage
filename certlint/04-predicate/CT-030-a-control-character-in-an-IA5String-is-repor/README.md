# CT-030 — a control character in an `IA5String` is reported as an error, and `IA5String` admits them

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | a real corpus certificate, one octet changed |

## Upstream issues, adjudicated

- **#3** — TeletexString/T61String *(open)*
  **related.** Same check, the control-character case rather than the repertoire case.

## Analysis

### The code

```ruby
elsif (tag_class == :UNIVERSAL) && ([22, 26].include? tag)
  # IA5, Visible
  if value.bytes.any? { |b| b < 0x20 || b > 0x7E }
    messages << "E: Control character found in String in #{pdu}"
  end
```

Universal tag 22 is `IA5String` and tag 26 is `VisibleString`. One predicate
is applied to both.

### What the defining document says

ITU-T X.680 (02/2021) Table 8, *List of restricted character string types*,
gives each type its repertoire by ISO 2375 registration number:

| type | tag | defining registration numbers |
|---|---|---|
| `TeletexString (T61String)` | 20 | 6, 87, 102, 103, 106, 107, 126, 144, 150, 153, 156, 164, 165, 168 **+ SPACE + DELETE** |
| `IA5String` | 22 | **1**, 6 + SPACE + DELETE |
| `VisibleString (ISO646String)` | 26 | 6 + SPACE |

Registration **6** is the ISO/IEC 646 IRV *graphic* set, `0x21`–`0x7E`.
Registration **1** is the ISO/IEC 646 **C0 control set**, `0x00`–`0x1F`.

So the predicate is correct for tag 26 — `VisibleString` is graphic set plus
SPACE, with no control set and, unlike the two types above it in the table, no
DELETE — and wrong for tag 22. `IA5String` admits every C0 control character
*and* DELETE by the definition of the type. certlint reports a conforming
encoding as an `E:`.

certlint cites no clause here, so this is a comparison against the document
that defines the type rather than against a citation the tool chose.

### Reproduction

a certificate from Mozilla CA incident [bug
1195115](https://bugzilla.mozilla.org/show_bug.cgi?id=1195115), whose subject
carries an `emailAddress` attribute — `EmailAddress ::= IA5String`, RFC 5280
Appendix A. One content octet of that `IA5String` changed from `0x6e` to
`0x09`, HORIZONTAL TAB, at file offset 341. Same length, so nothing else in
the encoding moves.

```
observed   E: Control character found in String in Certificate
           E: Control character found in String in EmailAddress
correct    nothing: 0x09 is a character of IA5String (X.680 Table 8,
           registration 1)
```

The control file produces neither message. asn1c's own constraint check is
silent on both files, so the finding is entirely certlint's Ruby-side test —
the compiled grammar does not agree with it.

### Suggested fix

Split the branch. Keep `0x20..0x7E` for tag 26. For tag 22 test the type's
actual bound — `b > 0x7F` — and leave the value question to whatever knows
what the field must hold. certlint already has that knowledge for the field
where it matters: the URI checks in `cablint.rb`.
