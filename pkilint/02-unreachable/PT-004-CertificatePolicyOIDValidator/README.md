# PT-004 — a validator class is never instantiated, and four documented codes can never fire

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `02-unreachable` — Checks that cannot fire |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

`CertificatePolicyOIDValidator` (`certificate_extension.py:65`) declares four
findings:

| code | severity |
|---|---|
| `pkix.required_certificate_policy_oid_missing` | ERROR |
| `pkix.conflicting_certificate_policy_oids` | ERROR |
| `pkix.unknown_certificate_policy_oid` | ERROR |
| `pkix.anypolicy_certificate_policy_in_end_entity_certificate` | WARNING |

**The class is referenced exactly once in the whole repository — by its own
`class` statement.**

```
$ grep -rn "CertificatePolicyOIDValidator" . | grep -v '\.pyc'
pkilint/pkix/certificate/certificate_extension.py:65:class CertificatePolicyOIDValidator(validation.Validator):
```

Every sibling in the file is wired into `pkilint/pkix/certificate/__init__.py`
(lines 356–407) or, for `IssuerSubjectPolicyChainValidator`, into
`bin/lint_pkix_signer_signee_cert_chain.py`. This one is wired nowhere, so no
validator container holds it and no profile can emit its codes.

Confirmed against pkilint's own published catalogue rather than by reading, by
building each shipped profile and dumping
`report.report_included_validations`:

```python
from pkilint.pkix import certificate, name, extension
from pkilint import report
dv = certificate.create_pkix_certificate_validator_container(
    certificate.create_decoding_validators(
        name.ATTRIBUTE_TYPE_MAPPINGS, extension.EXTENSION_MAPPINGS),
    [certificate.create_issuer_validator_container([]),
     certificate.create_validity_validator_container(),
     certificate.create_subject_validator_container([]),
     certificate.create_extensions_validator_container([]),
     certificate.create_spki_validator_container([])])
# csv, columns: severity,code
```

stock PKIX certificate profile 93 codes all four ABSENT 22 serverauth
profiles, unioned 336 codes all four ABSENT

**Controls ran in the same dumps and passed**, which is what makes the absence
readable: `pkix.certificate_skid_end_entity_missing`, `pkix.no_ku_bits_set`,
`pkix.issuer_alt_name_extension_critical` and
`pkix.name_constraints_no_subtrees` are PRESENT in the PKIX dump, and
`cabf.certificate_extensions_missing` and `pkix.no_ku_bits_set` are PRESENT in
the serverauth union. A dump that found nothing would have shown the suspects
absent too.

The two codes from `IssuerSubjectPolicyChainValidator` —
`pkix.certificate_subject_has_policy_not_in_issuer` and
`pkix.certificate_has_no_certificate_policies_extension` — are also ABSENT
from the single-certificate profile, and that one is *correct*: they need the
two-document chain linter. It is the same dump distinguishing the two cases.

observed four codes documented in source, emittable by no shipped profile
correct either wire the validator into a container, or remove the class

**Why it matters beyond the four codes.** pkilint's catalogue is what the
coverage gate's denominator is drawn from. A code that exists in source and in
no catalogue is counted by a source-denominator sweep and not by a
firing-denominator one, and the difference is invisible unless someone builds
the profiles and looks.
