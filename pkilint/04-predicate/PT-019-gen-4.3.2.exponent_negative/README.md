# PT-019 — `gen-4.3.2.exponent_negative` reports a conformant fractional amount

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | `pkilint 0.13.3`, reproduced on a modified copy of zlint's own fixture |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

`QcEuLimitValueValidator` (`pkilint/etsi/en_319_412_5.py`) reports a
`MonetaryValue` whose exponent is below zero:

```python
if node.children["exponent"].pdu < 0:
    findings.append(validation.ValidationFindingEncountered(
        self.VALIDATION_EXPONENT_NEGATIVE, None))
```

EN 319 412-5 states no such requirement, in any of its seven editions. § 4.3.2
gives the syntax and one comment:

```
MonetaryValue::= SEQUENCE {
    currency        Iso4217CurrencyCode,
    amount          INTEGER,
    exponent        INTEGER}
   -- value = amount * 10^exponent
```

The exponent is a power of ten applied to the amount. A negative exponent is
how the structure expresses a fractional amount — `EUR`, amount 10, exponent
−2 is a limit of €0.10 — and prohibiting it makes every sub-unit limit
unrepresentable. The two numbered requirements the clause carries,
QCS-4.3.2-01 and QCS-4.3.2-02, are both about the currency code; neither
mentions the exponent, and no edition adds a third.

The class docstring says the intent in as many words — "Positive amount and
exponent value" — so this is the code matching its author's note and both
diverging from the document they cite.

**Reproduction** — patch zlint's `QcStmtValidLimitValue.pem`, whose
`MonetaryValue` is `EUR`, amount 10, exponent 2, changing the one exponent
octet from `02` to `FE`:

```
ERROR etsi.en_319_412_5.gen-4.3.2.exponent_negative
```

The certificate now declares a transaction limit of €0.10 and is reported at
the error floor for it.

**A second, latent defect at the same site.** The line above appends a
`validation.ValidationFindingEncountered` — an `Exception` subclass — to a
list whose other three entries are `validation.ValidationFindingDescription`,
a `NamedTuple`. The two share `.finding` and `.message`, so the JSON report
path renders it correctly and **this is not observable in that path**; it was
checked rather than assumed. Any consumer that treats a finding description as
a tuple would see the difference. Reported here as a note, not as a claim of
breakage.

**Suggested repair.** Delete the exponent test. If a bound is wanted, it has
to come from a document that states one.
