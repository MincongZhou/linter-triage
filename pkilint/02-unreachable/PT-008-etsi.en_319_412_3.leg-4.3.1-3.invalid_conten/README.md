# PT-008 — two EN 319 412-3 key-usage findings can never fire

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `02-unreachable` — Checks that cannot fire |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

`etsi_shared.KeyUsageValidator.validate` reaches both findings only inside one
guard:

```python
if self._is_content_commitment_type is not None:
    if self._is_content_commitment_type:
        if setting not in self._CONTENT_COMMITMENT_SETTINGS:
            raise ...(self._validation_invalid_content_commitment_setting)
        elif setting != self.KeyUsageSetting.A:
            raise ...(self._validation_non_preferred_content_commitment_setting)
```

`en_319_412_3.LegalPersonKeyUsageValidator` passes those two findings up, and
`etsi/__init__.py:352` is its only construction site:

```python
extension_validators.append(
    en_319_412_3.LegalPersonKeyUsageValidator(is_content_commitment_type=None)
)
```

**`None` for every certificate type, established by executing it** rather than
by reading — the profile is built for all 40 members of
`etsi_constants.CertificateType` and every instantiation walked:

```python
found = []
def walk(v):
    if isinstance(v, en_319_412_3.LegalPersonKeyUsageValidator):
        found.append(v._is_content_commitment_type)
    for c in getattr(v, 'validators', []) or []: walk(c)
for t in etsi_constants.CertificateType:
    for v in etsi.create_validators(t): walk(v)
# -> 7 instantiations, every one of them None
```

The natural-person sibling in `en_319_412_2` is the contrast that makes this a
slip rather than a design: `etsi/__init__.py` passes
`is_content_commitment_type=True` to `NaturalPersonKeyUsageValidator` for the
`QCP_N` types and `None` otherwise, so the same code path works there. The
legal-person side has no equivalent arm because pkilint's `CertificateType`
enumeration models no e-seal certificate type at all.

### Reproduction

**observed** — nothing about LEG-4.3.1-3 on the type C certificate, and on the
type B certificate only the mixed-usage warning of the paragraph LEG-4.3.1-2
imports. **correct** — `leg-4.3.1-3.invalid_content_commitment_setting` on the
first and `leg-4.3.1-4.non_preferred_content_commitment_setting` on the
second.

Both codes are in `lint_etsi_cert validations -t
NCP-LEGAL-PERSON-CERTIFICATE`, so pkilint's own catalogue advertises checks it
cannot perform.

### Fix

One line, plus a decision. The mechanical part is to give
`LegalPersonKeyUsageValidator` a real `is_content_commitment_type`; the
substantive part is what decides it, and pkilint has no field for it today.

### Severity
