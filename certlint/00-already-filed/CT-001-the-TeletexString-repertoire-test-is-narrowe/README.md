# CT-001 — the `TeletexString` repertoire test is narrower than the type, DELETE included

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `00-already-filed` — Already on your issue tracker |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | a real corpus certificate, one octet changed |
| **Would otherwise sit in** | see the adjudication below |

## Upstream issues, adjudicated

- **#3** — TeletexString/T61String *(open)*
  **duplicate.** Open since 2020, from a reporter who read T.61 itself: the TeletexString check on certlint.rb:149 tests the wrong repertoire. Same claim, still unfixed.

## Analysis

### The code

```ruby
if tag == 20
  unless escape || value.force_encoding('BINARY').bytes.all? { |b|
      (b >= 0x20 && b <= 0x5B) || b == 0x5D || b == 0x5F ||
      (b >= 0x61 && b <= 0x7A) || b == 0x7C }
    messages << "E: Incorrectly encoded TeletexString in #{pdu}"
  end
```

The permitted set is a subset of `0x20`–`0x7C`.

### What the defining document says

X.680 Table 8, quoted above, gives `TeletexString (T61String)` **fourteen**
registration numbers "+ SPACE + DELETE", and X.690 (02/2021) §8.23.5 says the
octet string "shall contain the octets specified in ISO/IEC 2022 for encodings
in an 8-bit environment", with §8.23.5.2 and Table 3 assigning registration
102 as the assumed G0 set and 106/107 as the assumed C0/C1 sets, and explicit
escape sequences **allowed** for this type. The repertoire therefore spans
both halves of the octet range and is reachable by escape sequence beyond
that.

certlint's set omits DELETE, omits every octet above `0x7C`, and omits the
whole supplementary graphic area the type's own registrations define. The
narrowest demonstration is DELETE, because Table 8 names it in the same cell
as the registration numbers and no interpretation is required.

### Reproduction

a certificate from Mozilla CA incident [bug
1390979](https://bugzilla.mozilla.org/show_bug.cgi?id=1390979), whose
`commonName` is a `TeletexString`. One content octet changed from `0x65` to
`0x7f`, DELETE, at file offset 303.

```
observed   E: Incorrectly encoded TeletexString in Certificate
           E: Incorrectly encoded TeletexString in X520CommonName
correct    nothing: DELETE is named in TeletexString's own row of X.680 Table 8
```

The control file produces neither message, and asn1c's constraint check is
again silent on both.

### Suggested fix

None that is cheap. Testing a `TeletexString` against its actual repertoire
needs the ISO 2375 register entries for all fourteen sets and an ISO 2022
shift state machine, which is a substantial piece of work for a type RFC 5280
§4.1.2.4 already discourages. A narrower and honest alternative is to report
the *type* rather than the octets — cablint already does, with `W: … is using
deprecated TeletexString` — and drop the repertoire test.

Nothing shipped, and the site recorded as a `defect` in the lane ledger. A
faithful port would carry this bug, and the correct predicate is not
sourceable from this tree: `Specs/itu/` holds X.680 and X.690 but not the ISO
International Register entries the table points at. See `MANIFEST.md` for lane
`cl-g`.

## What was not verified
