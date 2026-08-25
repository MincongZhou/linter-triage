# pkilint — 39 confirmed defects

Reproduced against `digicert/pkilint` at **0.13.3**. Invocation: `lint_cabf_serverauth_cert <cert.pem>`.

Numbered `PT-001`..`PT-039`, contiguous.

Your issue tracker was read on 2026-08-24 (94 issues, 7 open). Each entry says what it found.

| | group | what is wrong | today |
|---|---|---|---|
| [`PT-001`](01-dating/PT-001-RFC-6818-replaced-RFC-5280-s-explicitText-ru/) | `dating` | RFC 6818 replaced RFC 5280's `explicitText` rule with its opposite, and both run | Medium |
| [`PT-002`](01-dating/PT-002-cabf.internal_domain_name/) | `dating` | `cabf.internal_domain_name` reports two shapes that are not internal names | Medium |
| [`PT-003`](01-dating/PT-003-a-withdrawn-requirement-and-its-replacement/) | `dating` | a withdrawn requirement and its replacement are both applied to every certificate | High |
| [`PT-004`](02-unreachable/PT-004-CertificatePolicyOIDValidator/) | `unreachable` | `CertificatePolicyOIDValidator` — a validator class is never instantiated, and four documented codes can never fire | Medium |
| [`PT-005`](02-unreachable/PT-005-the-one-branch-that-distinguishes-that-class/) | `unreachable` | the one branch that distinguishes that class raises `TypeError` on a `set` | Low |
| [`PT-006`](02-unreachable/PT-006-NaturalPersonSubjectAttributeAllowanceValida/) | `unreachable` | `NaturalPersonSubjectAttributeAllowanceValidator` — NAT-4.2.4-1's "no name attribute" branch cannot be reached | Medium |
| [`PT-007`](02-unreachable/PT-007-gen-5.1.1.qc_eu_pds_missing/) | `unreachable` | `gen-5.1.1.qc_eu_pds_missing` can never be reported | Medium |
| [`PT-008`](02-unreachable/PT-008-etsi.en_319_412_3.leg-4.3.1-3.invalid_conten/) | `unreachable` | `etsi.en_319_412_3.leg-4.3.1-3.invalid_content_commitment_setting` — two EN 319 412-3 key-usage findings can never fire | High |
| [`PT-009`](02-unreachable/PT-009-etsi.en_319_412_4.web-4.1.3-4.eku_missing/) | `unreachable` | `etsi.en_319_412_4.web-4.1.3-4.eku_missing` — `web-4.1.3-4.eku_missing` is installed only where its own predicate cannot hold | Medium |
| [`PT-010`](02-unreachable/PT-010-cabf.serverauth.ca_first_policy_oid_not_rese/) | `unreachable` | `cabf.serverauth.ca_first_policy_oid_not_reserved` — the first-policy-OID recommendation is unreachable on a certificate that | Medium |
| [`PT-011`](02-unreachable/PT-011-pkix.crl_signature_algorithm_match/) | `unreachable` | `pkix.crl_signature_algorithm_match` can never fire | High |
| [`PT-012`](03-scope/PT-012-the-S-MIME-profile-detects-that-a-certificat/) | `scope` | the S/MIME profile detects that a certificate is a CA, says so, and applies every Subscriber requirement anyway | High |
| [`PT-013`](04-predicate/PT-013-a-self-issued-certificate-is-a-root-CA-whate/) | `predicate` | a self-issued certificate is a root CA whatever its basicConstraints says | High |
| [`PT-014`](04-predicate/PT-014-pkix.invalid_uri_syntax/) | `predicate` | `pkix.invalid_uri_syntax` — a URI syntax check delegated to a library stricter than RFC 3986 | Low |
| [`PT-015`](04-predicate/PT-015-a-self-issued-certificate-is-typed-a-Root-CA/) | `predicate` | a self-issued certificate is typed a Root CA before anything asks whether it is a CA | High |
| [`PT-016`](04-predicate/PT-016-the-commonName-from-SAN-check-compares-DNS-n/) | `predicate` | the commonName-from-SAN check compares DNS names case-sensitively | Medium |
| [`PT-017`](04-predicate/PT-017-cabf.smime.prohibited_signature_algorithm_en/) | `predicate` | `cabf.smime.prohibited_signature_algorithm_encoding`'s allow-list has no entry for ECDSA-with-SHA-512 | Medium |
| [`PT-018`](04-predicate/PT-018-the-organizationIdentifier-state-province-fo/) | `predicate` | the organizationIdentifier state/province format check enforces a format its own comment says is not yet adopted | Medium |
| [`PT-019`](04-predicate/PT-019-gen-4.3.2.exponent_negative/) | `predicate` | `gen-4.3.2.exponent_negative` reports a conformant fractional amount | Medium |
| [`PT-020`](04-predicate/PT-020-gen-5.2.3-1.nca_name_non_latin/) | `predicate` | `gen-5.2.3-1.nca_name_non_latin` tests ASCII, not the Latin alphabet | Medium |
| [`PT-021`](04-predicate/PT-021-Psd2CertificatePolicyOidPresenceValidator/) | `predicate` | `Psd2CertificatePolicyOidPresenceValidator` — `ovr-6.1-3.prohibited_psd2_policy_oid_present` reports the combination OVR-6.1-3 permits | Medium |
| [`PT-022`](04-predicate/PT-022-gen-5.2.1-3.invalid_psd_organization_id_form/) | `predicate` | `gen-5.2.1-3.invalid_psd_organization_id_format` reports the alternative GEN-5.2.1-4 provides, at error level | Medium |
| [`PT-023`](04-predicate/PT-023-etsi.en_319_412_4.web-4.1.4-2.common_name_un/) | `predicate` | `etsi.en_319_412_4.web-4.1.4-2.common_name_unknown_source` — the ETSI commonName check contradicts pkilint's own Forum check on one certificate | Medium |
| [`PT-024`](04-predicate/PT-024-cabf.serverauth.ca_first_policy_oid_not_rese/) | `predicate` | `cabf.serverauth.ca_first_policy_oid_not_reserved` — the first-policy-OID recommendation fires on certificates with no reserved | Medium |
| [`PT-025`](04-predicate/PT-025-pkix.crl_unspecified_crl_entry_reason_code/) | `predicate` | `pkix.crl_unspecified_crl_entry_reason_code` is never registered | High |
| [`PT-026`](04-predicate/PT-026-a-CA-certificate-asserting-id-kp-timeStampin/) | `predicate` | a CA certificate asserting `id-kp-timeStamping` is reported as carrying an | High |
| [`PT-027`](04-predicate/PT-027-no-certificate-can-be-typed-as-a-cross-certi/) | `predicate` | no certificate can be typed as a cross-certified subordinate CA under | Low |
| [`PT-028`](05-spec-reading/PT-028-a-clause-that-says-may-is-reported-as-an-ERR/) | `spec-reading` | a clause that says "may" is reported as an ERROR | Medium |
| [`PT-029`](05-spec-reading/PT-029-KeyUsageValidator/) | `spec-reading` | `KeyUsageValidator` — a `pkix.` code enforces a rule RFC 5280 does not state and RFC 5480 withdrew | Low |
| [`PT-030`](05-spec-reading/PT-030-PolicyConstraintsPresenceValidator/) | `spec-reading` | `PolicyConstraintsPresenceValidator` — two clauses that describe a scope are reported as ERROR | Medium |
| [`PT-031`](06-parser/PT-031-a-keyUsage-that-will-not-decode-silences-eve/) | `parser` | a keyUsage that will not decode silences every keyUsage check | High |
| [`PT-032`](06-parser/PT-032-an-extension-that-will-not-decode-picks-the/) | `parser` | an extension that will not decode picks the wrong certificate profile | High |
| [`PT-033`](06-parser/PT-033-a-UniversalString-attribute-is-undecodable-a/) | `parser` | a `UniversalString` attribute is undecodable, and takes the whole certificate with it | High |
| [`PT-034`](07-robustness/PT-034-EcdsaKeyValidator/) | `robustness` | `EcdsaKeyValidator` — a validator crashes where it should be skipped | Medium |
| [`PT-035`](08-hygiene/PT-035-the-severity-catalogues-have-drifted-from-th/) | `hygiene` | the severity catalogues have drifted from the code | Medium |
| [`PT-036`](08-hygiene/PT-036-every-EV-Guidelines-citation-uses-superseded/) | `hygiene` | every EV Guidelines citation uses superseded numbering | Low |
| [`PT-037`](08-hygiene/PT-037-LegalPersonIssuerOrganizationAttributesEqual/) | `hygiene` | `LegalPersonIssuerOrganizationAttributesEqualityValidator` — the `organizationIdentifier` equality check cites GEN-4.2.3.1-3, which is a different requirement | Low |
| [`PT-038`](08-hygiene/PT-038-the-gen--label-prefix-does-not-exist-in-EN-3/) | `hygiene` | the `gen-` label prefix does not exist in EN 319 412-5, and two TS 119 495 citations name clauses that are not there | Low |
| [`PT-039`](08-hygiene/PT-039-a-finding-code-is-missing-a-word/) | `hygiene` | a finding code is missing a word | Low |

## Groups

### `01-dating` — Requirements applied to certificates that predate them (3)

The largest group after the predicate bugs, and the one most often read as a scope decision rather than a defect. Three shapes: a check with the wrong effective date, a check with none at all for a dated requirement, and reference data — a TLD list, a set of reserved names — treated as though today's contents had always held.

The common cause is an assumption that the tool only ever sees recent issuance. Certificate Transparency holds twenty years of it, and root certificates in use today were issued before most of these requirements existed. A date too late suppresses real findings; too early reports certificates that were conformant when they were issued, which is the more common direction here.

### `02-unreachable` — Checks that cannot fire (8)

Registered, documented, and reports nothing — a tautological condition, an unreachable branch, a class never instantiated. These read as coverage from outside and are not.

### `03-scope` — Applied outside the population the clause governs (1)

The predicate is right and the population is wrong. Almost all of these are false positives against conformant certificates.

### `04-predicate` — The test itself is wrong (15)

Guard bugs, the wrong field read, an off-by-one, a walker that cannot express the shape it looks for. Mostly false negatives: the check passes the thing it is named for.

### `05-spec-reading` — Differing analysis of the normative text (3)

We read a clause differently. Filed as disagreements rather than defects, and the ones most likely to end with the maintainer telling us we are wrong.

### `06-parser` — Root cause in the decoder, not in the check (3)

The check asks a reasonable question and the decoder returns an answer that cannot carry the distinction. Fixing these inside a check is usually wrong; documenting the limit may be the better remedy.

### `07-robustness` — Panics, run-ending failures, and non-determinism (1)

Defects in how the tool runs rather than in what it decides. These reach every consumer whatever they lint.

### `08-hygiene` — Descriptions, citations, severities and tests (5)

Nothing here changes a verdict. Included because they mislead a reader, or because a test asserts less than it appears to.

