# PT-033 — a `UniversalString` attribute is undecodable, and takes the whole certificate with it

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `06-parser` — Root cause in the decoder, not in the check |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool |
| **Cases** | positive/ |
| **Verified against** | `pkilint./repro.sh` (three certificates identical but for one CHOICE alternative, plus the decoder on all five) |

## Upstream issues, adjudicated

- **#182** — authorityKeyIdentifier extension MUST be included in all certificates (selfsigned) *(closed)*
  **unrelated.** Matched on the string pkix.authority_key_identifier_extension_absent. #182 is about the AKI requirement for self-signed roots; this entry is about X520CommonName's CHOICE alternatives.

## Analysis

RFC 5280 Appendix A.1 gives `DirectoryString` — and `X520CommonName`, which is
one — five alternatives:

```
X520CommonName ::= CHOICE {
      teletexString     TeletexString   (SIZE (1..ub-common-name)),
      printableString   PrintableString (SIZE (1..ub-common-name)),
      universalString   UniversalString (SIZE (1..ub-common-name)),
      utf8String        UTF8String      (SIZE (1..ub-common-name)),
      bmpString         BMPString       (SIZE (1..ub-common-name)) }
```

BR §7.1.4.2 requires `commonName` to use `UTF8String` or `PrintableString`, so
three of those five are prohibited, and pkilint has the check —
`AttributeValueDirectoryStringValidator` in
`cabf/serverauth/serverauth_name.py`:

```python
if directory_string_choice_name not in {"utf8String", "printableString"}:
    raise validation.ValidationFindingEncountered(
        self.VALIDATION_ATTRIBUTE_VALUE_INVALID_ENCODING,
        f"Invalid attribute value encoding: {directory_string_choice_name}",
    )
```

```
teletexString   (0x14): decoded
printableString (0x13): decoded
universalString (0x1C): REFUSED -- Pyasn1FasderError: Error reading TLV header
                        near substrate offset 0: unknown/unsupported ASN.1 DER tag: 0x1c
utf8String      (0x0C): decoded
bmpString       (0x1E): decoded
```

pyasn1's own decoder reads the same six bytes without complaint, so this is
the fast decoder's tag table, not a pyasn1 limitation and not a property of
DER.

The three fixtures differ in that one TLV and in nothing else:

| fixture | exit | at ERROR |
|---|---|---|
| `positive/PT-033-printablestring.pem` | 0 | *(nothing — the control)* |
| `positive/PT-033-bmpstring.pem` | 1 | `cabf.serverauth.attribute_value_invalid_encoding_type` |
| `positive/PT-033-universalstring.pem` | 1 | `Failed to load certificate` |

**Why High.** The refusal is not confined to the attribute — it kills the
document, so every validator pkilint would otherwise have run reports nothing
about that certificate: extensions, key usage, validity, SAN, all of it. The
question the [reporting
skill](../.claude/skills/linter-gap-reporting/SKILL.md) puts first is whether
the subject of a check can influence whether the check runs, and here a CA can
silence pkilint completely by encoding one subject attribute in a form RFC
5280 permits.

The exit code does not rescue a consumer either. `lint_cabf_serverauth_cert`
returns `clamp_exit_code(get_findings_count(...))` — the exit status *is* the
finding count — while the load failure returns a hardcoded `1`. "Unreadable"
and "exactly one finding" are therefore the same value, and the two cases are
distinguishable only by reading stderr. An API caller sees a `ValueError` out
of the document loader, which is at least an exception rather than an empty
list; a caller that catches it broadly gets silence.

**Fix.** Decode `UniversalString`. The reporting side is already implemented
and already correct; only the decoder's tag table needs the case, and the
report belongs to `pyasn1_fasder` rather than to pkilint itself.

**How it was found.** Not by looking for it. The 30 certificates
`e_ext_authority_key_identifier_missing` reports and
`pkix.authority_key_identifier_extension_absent` does not are all refused by
pkilint's loader, and reading *why* — rather than recording "refused" and
moving on — separated three causes, of which this is one. The other two are
not defects: an `extensions` field holding an empty SEQUENCE against
`Extensions ::= SEQUENCE SIZE (1..MAX)`, which is 25 of the 30, and an
explicitly encoded DEFAULT `version`. Both are genuinely malformed DER, and a
strict decoder is entitled to refuse them — the difference here is that
`universalString` is well-formed and permitted.

Claims investigated and refuted are in [REFUTED.md](REFUTED.md), with the
evidence. They carry no number.
