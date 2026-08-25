# PT-037 — the `organizationIdentifier` equality check cites GEN-4.2.3.1-3, which is a different requirement

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `08-hygiene` — Descriptions, citations, severities and tests |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | `pkilint 0.13.3`, read from the source and both editions |

## Upstream issues, adjudicated

- **#191** — Typos in reference for validation errors in en_319_412_1 *(closed)*
  **related.** #191 corrected en_319_412_1 findings that cited en_319_412_2/3. Closed and fixed before the pinned v0.13.3 -- verified absent from the pinned source. This entry is a different mis-citation the same pass did not reach.

## Analysis

`LegalPersonIssuerOrganizationAttributesEqualityValidator` declares

```python
VALIDATION_ORGID_ORGNAME_ATTRIBUTE_VALUES_EQUAL = validation.ValidationFinding(
    validation.ValidationFindingSeverity.ERROR,
    "etsi.en_319_412_2.gen-4.2.3.1-3.organization_id_and_organization_name_attribute_values_equal",
)
```

while the base class it extends, in `pkilint/etsi/etsi_shared.py`, documents
itself as

```
412-3 LEG-4.2.1-6 and 412-2 GEN-4.2.3.1-8: The organizationIdentifier attribute
shall contain an identification of the subject organization different from the
organization name.
```

The docstring is right and the code is wrong. In both editions that carry
numbered requirements:

| | v2.3.1 (2023-09) | v2.4.1 (2025-06) |
|---|---|---|
| GEN-4.2.3.1-3 | "If an appropriate registration number is known to exist, then the identity of the issuer shall contain organizationIdentifier" | same |
| GEN-4.2.3.1-8 | "The organizationIdentifier attribute shall contain an identification of the certificate issuing organization different from the organization name" | same |

`-3` requires the attribute to be *present* in a stated circumstance; `-8` is
the equality prohibition the validator implements. A CA reading the finding
code and turning to GEN-4.2.3.1-3 finds a requirement it did not breach.

The check itself is correct and nothing about the verdict changes, which is
why this is Low: it misleads a reader.

**Reproduction** — no certificate needed:

```
$ cd pkimetal-linters/pkilint
$ grep -n "gen-4.2.3.1-3" pkilint/etsi/en_319_412_2.py
614:        "etsi.en_319_412_2.gen-4.2.3.1-3.organization_id_and_organization_name_attribute_values_equal",
$ grep -n "GEN-4.2.3.1-8" pkilint/etsi/etsi_shared.py
190:    412-3 LEG-4.2.1-6 and 412-2 GEN-4.2.3.1-8: The organizationIdentifier attribute shall contain an identification of the subject organization
$ cd ../..                       # back to the research tree root
$ grep -n "GEN-4.2.3.1-3:\|GEN-4.2.3.1-8:" "Specs/etsi/EN 319 412-2 v2.4.1.txt"
412:GEN-4.2.3.1-3: If an appropriate registration number is known to exist, then the identity of the issuer shall contain
427:GEN-4.2.3.1-8: The organizationIdentifier attribute shall contain an identification of the certificate issuing
```

**Suggested repair.** Rename the code to
`etsi.en_319_412_2.gen-4.2.3.1-8.organization_id_and_organization_name_attribute_values_equal`.
A finding code is part of pkilint's published interface, so this is a rename
somebody has to schedule rather than a patch.

## What was not verified
