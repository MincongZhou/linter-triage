# PT-025 — `pkix.crl_unspecified_crl_entry_reason_code` is never registered

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | `pkilint 0.13.3`, reproduced on a fabricated `CertificateList` |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

`CrlReasonCodeValidator` (`pkilint/pkix/crl/crl_extension.py`) exists to warn
when a CRL entry's `reasonCode` is the `unspecified` (0) value — RFC 5280 §
5.3.1's "the reason code CRL entry extension SHOULD be absent instead of using
the unspecified (0) reasonCode value":

```python
class CrlReasonCodeValidator(validation.Validator):
    VALIDATION_UNSPECIFIED_REASON_CODE = validation.ValidationFinding(
        validation.ValidationFindingSeverity.WARNING,
        "pkix.crl_unspecified_crl_entry_reason_code",
    )

    def __init__(self):
        super().__init__(
            pdu_class=rfc5280.CRLReason,
            validations=[self.VALIDATION_UNSPECIFIED_REASON_CODE],
        )

    def validate(self, node):
        unspecified = rfc5280.CRLReason.namedValues["unspecified"]
        if node.pdu == unspecified:
            raise validation.ValidationFindingEncountered(
                self.VALIDATION_UNSPECIFIED_REASON_CODE
            )
```

Unlike PT-011, this class is not merely mismatched — it is never instantiated
anywhere. `grep -rn "CrlReasonCodeValidator\b"` across the whole `pkilint/`
and `tests/` trees returns exactly one line: the class definition itself.
`create_pkix_crl_validator_container` (`pkilint/pkix/crl/__init__.py`), which
is the only place any CRL validator is wired into the tool, lists twelve
validators and this is not one of them:

```python
validators += [
    crl_validator.VersionPresenceValidator(),
    crl_validator.CorrectVersionValidator(),
    crl_extension.CrlNumberPresenceValidator(),
    crl_extension.AuthorityKeyIdentifierPresenceValidator(),
    crl_validator.SignatureAlgorithmMatchValidator(),
    crl_validator.RevokedCertificatesEmptyValidator(),
    crl_extension.CrlReasonCodeCriticalityValidator(),
    time.UtcTimeCorrectSyntaxValidator(),
    time.GeneralizedTimeCorrectSyntaxValidator(),
    crl_validity.CrlSaneValidityPeriodValidator(),
    pkix.CertificateSerialNumberValidator(),
    crl_extension.CrlNumberValueValidator(),
    general_name.GeneralNameValidatorContainer(),
]
```

`lint_crl.py`, the tool's own CLI entry point, adds nothing beyond this
container for either `--profile PKIX` or `--profile BR`. There is no third
place a CRL validator could be wired in.

```python
from pkilint import pkix
from pkilint.pkix import crl, name, extension as ext_mod

doc_validator = crl.create_pkix_crl_validator_container(
    [pkix.create_attribute_decoder(name.ATTRIBUTE_TYPE_MAPPINGS),
     pkix.create_extension_decoder(ext_mod.EXTENSION_MAPPINGS)],
    [crl.create_issuer_validator_container([]),
     crl.create_validity_validator_container([]),
     crl.create_extensions_validator_container([])],
)
doc = crl.RFC5280CertificateList(der, der)  # der: one entry, reasonCode 0
doc.decode()
for res in doc_validator.validate(doc.root):
    for fd in res.finding_descriptions:
        print(fd.finding.code, fd.message)
```

Output on 0.13.3: nothing (confirmed against the class directly too —
`CrlReasonCodeValidator.validate(node)` on the same entry's `CRLReason` node
does raise `pkix.crl_unspecified_crl_entry_reason_code`, showing the class
itself is correct and the defect is purely in the wiring).

**Observed** — no finding, on a CRL entry carrying `reasonCode` `unspecified`
(0). **Correct** — `pkix.crl_unspecified_crl_entry_reason_code`, WARNING.

**Severity.** High, for the same reason as PT-011: unconditionally absent, not
suppressible by anything the subject controls, because the validator that
would raise it is never asked to run.

**Suggested repair.** Add `crl_extension.CrlReasonCodeValidator` to
`create_pkix_crl_validator_container`'s validator list.
