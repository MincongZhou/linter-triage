# PT-006 — NAT-4.2.4-1's "no name attribute" branch cannot be reached

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `02-unreachable` — Checks that cannot fire |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | `pkilint 0.13.3`, reproduced on a certificate from zlint's own fixture set |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

`NaturalPersonSubjectAttributeAllowanceValidator`
(`pkilint/etsi/en_319_412_2.py`) declares one finding for the whole of
NAT-4.2.4-1 and tests its three bullets in two branches:

```python
if not attrs_present.issuperset(self._REQUIRED_ATTRIBUTES):        # C, CN
    missing_attrs = self._REQUIRED_ATTRIBUTES - attrs_present
elif attrs_present.isdisjoint(self._PSEUDONYM_AND_NAME_ATTRIBUTES): # GN, SN, pseudonym
    missing_attrs = self._PSEUDONYM_AND_NAME_ATTRIBUTES - attrs_present
```

The second branch reports a subject naming no natural person. It cannot run
through the profile, because the profile decides *that this is a natural
person's certificate* by the same test, inverted. `determine_certificate_type`
in `pkilint/etsi/__init__.py`:

```python
is_natural_person = any((
    cert.get_subject_attributes_by_type(rfc5280.id_at_givenName),
    cert.get_subject_attributes_by_type(rfc5280.id_at_surname),
    cert.get_subject_attributes_by_type(rfc5280.id_at_pseudonym),
))
```

and every `NATURAL_PERSON_CERTIFICATE_TYPES` member is returned only inside
`if is_natural_person:`. `create_validators` installs the validator only for
those types. So the validator is given a subject only when at least one of the
three attributes is present, which is precisely the condition the branch tests
for the absence of.

**Reproduction** — run under the interpreter pkilint is installed into:

```
1. etsi.en_319_412_2.nat-4.2.4-1.required_attribute_missing -- Required attributes missing: 2.5.4.6
2. NCP_LEGAL_PERSON_CERTIFICATE natural person type? False
3. 9 types; all natural person? True
```

`qcSmimeNatural.pem` has `subject=CN=test` and asserts an EN 319 411-2 natural
person policy identifier. Line 1 shows the check has something to say about
it; lines 2 and 3 show it is never asked.

**What the certificate is reported for instead.** Because the type router
decides person-kind from the subject rather than from the certificate policy,
this certificate is typed `NCP_LEGAL_PERSON_CERTIFICATE` and judged against
**EN 319 412-3**:

```
ERROR  etsi.en_319_412_3.leg-4.2.1-2.country_attribute_absent
ERROR  etsi.en_319_412_3.leg-4.2.1-2.organization_identifier_attribute_absent
ERROR  etsi.en_319_412_3.leg-4.2.1-2.organization_name_attribute_absent
```

— three requirements from the profile for legal persons, on a certificate
whose policy says it was issued to a natural person, and no mention of
NAT-4.2.4-1.

**Suggested repair.** Decide person-kind from the certificate policy where one
of EN 319 411-2's identifiers is present, and fall back to the subject
attributes only where none is — `id-qcp-natural` and `id-qcp-natural-qscd` are
defined as policies for certificates issued to a natural person, so a
certificate asserting one is a natural person's certificate whatever its
subject managed to carry.
