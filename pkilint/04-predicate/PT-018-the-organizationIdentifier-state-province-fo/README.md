# PT-018 — the organizationIdentifier state/province format check enforces a format its own comment says is not yet adopted

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

`CabfOrganizationIdentifierValidatorBase` in `pkilint/cabf/cabf_name.py`
checks a present `state_province` component against:

```python
# the attribute name for this finding is prefixed with an underscore, so it's not flagged by the "validation report"
# test
_VALIDATION_ORGANIZATION_ID_INVALID_SP_FORMAT = validation.ValidationFinding(
    validation.ValidationFindingSeverity.ERROR,
    "cabf.invalid_organization_identifier_state_province_format",
)
...
def validate_with_parsed_value(self, node, parsed):
    if (
        self._enforce_strict_state_province_format
        and parsed.state_province is not None
    ):
        if len(parsed.state_province) != 2 or not parsed.state_province.isalpha():
            raise validation.ValidationFindingEncountered(
                self._VALIDATION_ORGANIZATION_ID_INVALID_SP_FORMAT,
                f'State/province "{parsed.state_province}" is not two letters (will be fixed in erratum ballot)',
            )
```

The message the check raises names its own defect: **"will be fixed in erratum
ballot"**. The predicate enforces a stricter shape than either document
currently states, and the code says so.

```
pkilint/cabf/serverauth/__init__.py:186   CabfOrganizationIdentifierAttributeValidator()   # no kwarg -> True
pkilint/cabf/serverauth/serverauth_subscriber.py:49   enforce_strict_state_province_format=True
pkilint/cabf/smime/smime_name.py:316                  enforce_strict_state_province_format=False
```

So the check fires on the **serverauth population only**. The S/MIME path
passes `False` *and* sets `state_province=STATE_PROVINCE_PROHIBITED`, so the
S/MIME Baseline Requirements are not a document under which this finding can
be raised at all.

That sharpens the report rather than weakening it: pkilint already knows the
subdivision grammar is looser than two letters, because it switched the strict
reading off on the one path where it would otherwise apply. What remains is a
stricter-than-published check on the path governed by the document quoted
first below.

The two texts stating the grammar, read directly rather than inferred from the
check — the EV Guidelines because it governs the population the check runs on,
the S/MIME BR because it states the same shape and shows the reading is not
peculiar to one document:

- EV Guidelines § 7.1.4.2.8, Appendix H's grammar, current text: "a plus '+' … followed by an **up-to-three alphanumeric** character ISO 3166-2 identifier for the subdivision". - S/MIME BR, latest edition on this volume (`smime-br-1.0.15.txt` § 7.1.4.2.2(d)): "plus '+' … and **up-to-3 character** ISO 3166-2 identifier for the subdivision" — the same shape, one document reading "alphanumeric" where the other's adjacent sentence (Appendix A.1, GOV scheme) reads "up to three alphanumeric".

Neither document requires exactly two letters. The check's own inline comment
confirms the discrepancy is known and attributes it to an unlanded erratum,
not to a misreading on this lane's part.

**Executed, not just read.** `pkilint`'s own predicate, run against a
subdivision the current text permits:

```
$ ~/.venv/linters/bin/python3 -c "
sp = 'ABC'   # 3-character alphanumeric, permitted by both current texts
print(len(sp) != 2 or not sp.isalpha())"
True
```

`True` means the check fires. A Registration Reference such as
`NTRGB+ABC-12345678` — scheme `NTR`, country `GB`, subdivision `ABC`, three
alphanumeric characters exactly as Appendix H and § 7.1.4.2.2(d) describe — is
reported as malformed.

**Severity is Medium, not High.** The check does not verify conformance it
failed to check (it still rejects a genuinely malformed value) and a CA cannot
switch it off from the certificate; but it does report a real,
document-conformant Registration Reference as a defect, which is ground truth
downstream consumers of pkilint's output would get wrong until the erratum
lands — the "publishes ground truth others consume and it is wrong" case in
the severity table.

## What was not verified
