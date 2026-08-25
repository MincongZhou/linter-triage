# zlint — 94 confirmed defects

Reproduced against `zmap/zlint` at **v3.7.1-20-g1007b1d5**. Invocation: `zlint <cert.pem>`.

Numbered `ZT-001`..`ZT-094`, contiguous.

`ZT-001`..`ZT-068` are the numbers the 2026-08-19 package gave the same entries; `ZT-069` onward are new. Numbers are therefore not in group order.

Your issue tracker was read on 2026-08-24. Each entry says what it found.

| | group | what is wrong | today |
|---|---|---|---|
| [`ZT-001`](00-already-filed/ZT-001-six-subjectAltName-name-type-lints-hold-CA-c/) | `already-filed` | six subjectAltName name-type lints hold CA certificates to a Subscriber clause | Medium |
| [`ZT-002`](00-already-filed/ZT-002-e_ext_cert_policy_explicit_text_too_long/) | `already-filed` | `e_ext_cert_policy_explicit_text_too_long` measures bytes where RFC 6818 says characters | Medium |
| [`ZT-003`](00-already-filed/ZT-003-e_subject_dn_not_printable_characters/) | `already-filed` | `e_subject_dn_not_printable_characters` reads a BMPString's padding as U+0000 | Medium |
| [`ZT-004`](00-already-filed/ZT-004-e_ev_organization_id_missing/) | `already-filed` | `e_ev_organization_id_missing` holds Subordinate CAs to the EV Subscriber profile | High |
| [`ZT-005`](00-already-filed/ZT-005-e_key_usage_and_extended_key_usage_inconsist/) | `already-filed` | `e_key_usage_and_extended_key_usage_inconsistent` reports certificates that have a consistent purpose | Medium |
| [`ZT-006`](00-already-filed/ZT-006-e_ext_cert_policy_explicit_text_too_long/) | `already-filed` | `e_ext_cert_policy_explicit_text_too_long` counts bytes, not characters | Medium |
| [`ZT-007`](00-already-filed/ZT-007-e_subject_dn_not_printable_characters/) | `already-filed` | `e_subject_dn_not_printable_characters` reads raw octets, whatever the tag | Medium |
| [`ZT-008`](00-already-filed/ZT-008-e_qcstatem_mandatory_etsi_statems/) | `already-filed` | `e_qcstatem_mandatory_etsi_statems` reports a clause about EU qualified certificates against certificates that are not one | Medium |
| [`ZT-009`](00-already-filed/ZT-009-e_ext_duplicate_extension/) | `already-filed` | `e_ext_duplicate_extension` joins unsorted map keys into its details | Low |
| [`ZT-010`](01-dating/ZT-010-util.CABV201Date/) | `dating` | `util.CABV201Date` is the effective date of a different ballot | Medium |
| [`ZT-011`](01-dating/ZT-011-e_excessively-backdated-is-switched-off-by-t/) | `dating` | `e_excessively backdated` is switched off by the field it polices | High |
| [`ZT-012`](01-dating/ZT-012-e_mp_ecdsa_signature_encoding_correct/) | `dating` | `e_mp_ecdsa_signature_encoding_correct` — the MRSP ECDSA encoding lints are dated five years late | High |
| [`ZT-013`](01-dating/ZT-013-two-superseded-validity-lints-never-stop-app/) | `dating` | two superseded validity lints never stop applying | Low |
| [`ZT-014`](01-dating/ZT-014-two-root-keyUsage-lints-are-dated-13-years-b/) | `dating` | two root keyUsage lints are dated 13 years before the document they cite | Medium |
| [`ZT-015`](01-dating/ZT-015-e_root_ca_key_usage_must_be_critical/) | `dating` | `e_root_ca_key_usage_must_be_critical` dates a Baseline Requirement to 1999 | Medium |
| [`ZT-016`](01-dating/ZT-016-e_dnsname_empty_label/) | `dating` | `e_dnsname_empty_label` is dated to the document, not to its clause | Medium |
| [`ZT-017`](01-dating/ZT-017-e_qcstatem_qctype_oneonly/) | `dating` | `e_qcstatem_qctype_oneonly` takes its date from a constant naming a different document | Medium |
| [`ZT-018`](01-dating/ZT-018-e_qcstatem_pds_must_have_https_only/) | `dating` | `e_qcstatem_pds_must_have_https_only` is dated ten years after its clause | Medium |
| [`ZT-019`](01-dating/ZT-019-e_etsi_natural_person_key_usage_mandatory/) | `dating` | `e_etsi_natural_person_key_usage_mandatory` is dated four years after its clause | Medium |
| [`ZT-020`](01-dating/ZT-020-e_cs_rsa_key_size/) | `dating` | `e_cs_rsa_key_size` is dated 22 months before the RSA-3072 deadline | Medium |
| [`ZT-021`](01-dating/ZT-021-e_signature_algorithm_not_supported/) | `dating` | `e_signature_algorithm_not_supported` is undated and reports pre-Baseline-Requirements certificates | Medium |
| [`ZT-022`](02-unreachable/ZT-022-e_subject_not_dn/) | `unreachable` | `e_subject_not_dn` is a tautology and can never fire | High |
| [`ZT-023`](02-unreachable/ZT-023-e_generalized_time_does_not_include_seconds/) | `unreachable` | `e_generalized_time_does_not_include_seconds` — two GeneralizedTime lints are unreachable by construction | High |
| [`ZT-024`](02-unreachable/ZT-024-e_rsa_exp_negative/) | `unreachable` | `e_rsa_exp_negative` — the two RSA structure lints have no reachable input | High |
| [`ZT-025`](02-unreachable/ZT-025-e_crl_unique_revoked_certificate/) | `unreachable` | `e_crl_unique_revoked_certificate` has no reachable Error branch | High |
| [`ZT-026`](02-unreachable/ZT-026-e_qcstatem_qctype_valid/) | `unreachable` | `e_qcstatem_qctype_valid`'s error path is unreached, and its test asserts nothing | Medium |
| [`ZT-027`](03-scope/ZT-027-the-serverAuth-pre-flight-filter-suppresses/) | `scope` | the serverAuth pre-flight filter suppresses BR-wide requirements | Medium |
| [`ZT-028`](03-scope/ZT-028-IsDelegatedOCSPResponderCert-calls-any-OCSPS/) | `scope` | `IsDelegatedOCSPResponderCert` calls any OCSPSigning EKU a delegated responder | Medium |
| [`ZT-029`](03-scope/ZT-029-three-e_sub_cert_-lints-hold-CA-certificates/) | `scope` | three `e_sub_cert_*` lints hold CA certificates to the Subscriber profile | Medium |
| [`ZT-030`](03-scope/ZT-030-e_sub_cert_or_sub_ca_using_sha1/) | `scope` | `e_sub_cert_or_sub_ca_using_sha1` fires on a root its own Description excludes | Medium |
| [`ZT-031`](03-scope/ZT-031-e_mailbox_validated_allowed_subjectdn_attrib/) | `scope` | `e_mailbox_validated_allowed_subjectdn_attributes` judges CA certificates against a subscriber table | Medium |
| [`ZT-032`](03-scope/ZT-032-e_algorithm_identifier_improper_encoding/) | `scope` | `e_algorithm_identifier_improper_encoding` has no scope test | Medium |
| [`ZT-033`](03-scope/ZT-033-e_sub_cert_or_sub_ca_using_sha1/) | `scope` | `e_sub_cert_or_sub_ca_using_sha1` applies to Root CA certificates | Medium |
| [`ZT-034`](04-predicate/ZT-034-e_sub_cert_cert_policy_empty/) | `predicate` | `e_sub_cert_cert_policy_empty` passes the empty extension it names | High |
| [`ZT-035`](04-predicate/ZT-035-e_distribution_point_incomplete/) | `predicate` | `e_distribution_point_incomplete` gates the general rule behind the special case | High |
| [`ZT-036`](04-predicate/ZT-036-e_crlissuer_must_not_be_present_in_cdp/) | `predicate` | `e_crlissuer_must_not_be_present_in_cdp` cannot see the shape its body checks | High |
| [`ZT-037`](04-predicate/ZT-037-util.IsOnionV2Address/) | `predicate` | `util.IsOnionV2Address` reads the wrong label | High |
| [`ZT-038`](04-predicate/ZT-038-e_generalized_time_includes_fraction_seconds/) | `predicate` | `e_generalized_time_includes_fraction_seconds` fires where no fraction exists | Medium |
| [`ZT-039`](04-predicate/ZT-039-e_missing_crl_distrib_point/) | `predicate` | `e_missing_crl_distrib_point` tests for an OCSP URI where the clause names an accessMethod | Medium |
| [`ZT-040`](04-predicate/ZT-040-e_key_usage_incorrect_length/) | `predicate` | `e_key_usage_incorrect_length` measures the highest set bit, not the declared length | High |
| [`ZT-041`](04-predicate/ZT-041-e_rsa_fermat_factorization/) | `predicate` | `e_rsa_fermat_factorization` steps past the one modulus anybody can factor instantly | High |
| [`ZT-042`](04-predicate/ZT-042-e_invalid_legacy_spki_algoid/) | `predicate` | `e_invalid_legacy_spki_algoid` runs the other lint's allow-list | Medium |
| [`ZT-043`](04-predicate/ZT-043-e_utf8_latin1_mixup/) | `predicate` | `e_utf8_latin1_mixup` reads only the first value of each field | Medium |
| [`ZT-044`](05-spec-reading/ZT-044-e_signature_algorithm_not_supported/) | `spec-reading` | `e_signature_algorithm_not_supported` escalates RSASSA-PSS from its own warning to an error | Medium |
| [`ZT-045`](05-spec-reading/ZT-045-the-two-oldest-validity-lints-measure-the-Va/) | `spec-reading` | the two oldest validity lints measure the Validity Period exclusively | Medium |
| [`ZT-046`](05-spec-reading/ZT-046-e_subject_postal_code_max_length/) | `spec-reading` | `e_subject_postal_code_max_length` bounds a DN attribute with an X.400 constant | Medium |
| [`ZT-047`](05-spec-reading/ZT-047-e_subject_contains_noninformational_value/) | `spec-reading` | `e_subject_contains_noninformational_value` enforces a clause against the attribute that clause excepts | Medium |
| [`ZT-048`](06-parser/ZT-048-an-out-of-range-iPAddress-SAN-becomes-silenc/) | `parser` | an out-of-range `iPAddress` SAN becomes silence, not a finding | Medium |
| [`ZT-049`](06-parser/ZT-049-e_crl_auth_key_id_only_contains_keyid/) | `parser` | `e_crl_auth_key_id_only_contains_keyid` cannot see the field it forbids | High |
| [`ZT-050`](06-parser/ZT-050-a-root-CA-whose-signature-zcrypto-cannot-ver/) | `parser` | a root CA whose signature zcrypto cannot verify is linted as a subordinate CA | High |
| [`ZT-051`](06-parser/ZT-051-e_ext_cert_policy_disallowed_any_policy_qual/) | `parser` | `e_ext_cert_policy_disallowed_any_policy_qualifier` — a do-while walker cannot express an empty `SEQUENCE OF`, and three lints abstain | Low |
| [`ZT-052`](06-parser/ZT-052-a-keyUsage-that-did-not-decode-is-indistingu/) | `parser` | a `keyUsage` that did not decode is indistinguishable from one asserting no bits | High |
| [`ZT-053`](06-parser/ZT-053-a-root-whose-signature-algorithm-the-parser/) | `parser` | a root whose signature algorithm the parser declines is judged as a subordinate CA | High |
| [`ZT-054`](06-parser/ZT-054-zcrypto-s-DSA-verification-omits-the-FIPS-18/) | `parser` | zcrypto's DSA verification omits the FIPS 186-4 hash truncation | Medium |
| [`ZT-055`](07-robustness/ZT-055-a-parse-failure-ends-the-run-and-discards-th/) | `robustness` | a parse failure ends the run and discards the queue | High |
| [`ZT-056`](07-robustness/ZT-056-e_org_validated_invalid_cn/) | `robustness` | `e_org_validated_invalid_cn` panics on the subject shape its own clause permits | Medium |
| [`ZT-057`](07-robustness/ZT-057-GetKeyUsageStrings-ranges-over-a-map-so-two/) | `robustness` | `GetKeyUsageStrings` ranges over a map, so two lints print non-deterministic details | Low |
| [`ZT-058`](07-robustness/ZT-058-e_org_validated_invalid_cn/) | `robustness` | `e_org_validated_invalid_cn` panics on an OV S/MIME certificate with no organizationName | Medium |
| [`ZT-059`](07-robustness/ZT-059-e_ext_cannot_be_empty_sequence/) | `robustness` | `e_ext_cannot_be_empty_sequence` returns inside a map range, so which of several defective extensions it reports is a coin toss | Medium |
| [`ZT-060`](08-hygiene/ZT-060-a-test-names-a-fixture-it-does-not-lint/) | `hygiene` | a test names a fixture it does not lint | Medium |
| [`ZT-061`](08-hygiene/ZT-061-n_multiple_subject_rdn/) | `hygiene` | `n_multiple_subject_rdn` — six lints carry a Go identifier where a citation belongs | Low |
| [`ZT-062`](08-hygiene/ZT-062-two-lints-anchor-against-a-value-that-may-be/) | `hygiene` | two lints anchor `+` against a value that may be empty | Low |
| [`ZT-063`](08-hygiene/ZT-063-e_subscribers_crl_distribution_points_are_ht/) | `hygiene` | `e_subscribers_crl_distribution_points_are_http` reports an extension that is absent | Low |
| [`ZT-064`](08-hygiene/ZT-064-w_qcstatem_qcpds_lang_case/) | `hygiene` | `w_qcstatem_qcpds_lang_case` returns Error, which its own name denies | Low |
| [`ZT-065`](08-hygiene/ZT-065-e_rsa_public_exponent_too_small/) | `hygiene` | `e_rsa_public_exponent_too_small` publishes another lint's description | Low |
| [`ZT-066`](08-hygiene/ZT-066-e_wrong_time_format_pre2050/) | `hygiene` | `e_wrong_time_format_pre2050` names a correction that cannot be made | Low |
| [`ZT-067`](08-hygiene/ZT-067-w_subject_common_name_included/) | `hygiene` | `w_subject_common_name_included` applies the Baseline Requirements' word to EV certificates, whose subject the Baseline Requirements defer | Low |
| [`ZT-068`](09-absent/ZT-068-e_ca_key_usage_missing/) | `absent` | `e_ca_key_usage_missing` — no lint reports a subscriber certificate with no keyUsage | Medium |
| [`ZT-069`](01-dating/ZT-069-e_crl_extensions_validity/) | `dating` | `e_crl_extensions_validity` returns two severities, and is undated for a 2023 table | Medium |
| [`ZT-070`](01-dating/ZT-070-w_ext_policy_map_not_critical/) | `dating` | `w_ext_policy_map_not_critical`'s effective date reports certificates that were compliant when issued | Medium |
| [`ZT-071`](01-dating/ZT-071-w_ext_cert_policy_explicit_text_not_nfc/) | `dating` | `w_ext_cert_policy_explicit_text_not_nfc` mis-cites its document, mis-dates the `UTF8String` half of its own requirement, and misspells the citation it does carry | Low |
| [`ZT-072`](01-dating/ZT-072-n_ecdsa_ee_invalid_ku/) | `dating` | `n_ecdsa_ee_invalid_ku` is dated from a document it does not cite | Medium |
| [`ZT-073`](01-dating/ZT-073-w_sub_ca_certificate_policies_marked_critica/) | `dating` | `w_sub_ca_certificate_policies_marked_critical` has no `IneffectiveDate`, understating severity after BR 2.0.0 | Medium |
| [`ZT-074`](01-dating/ZT-074-w_sub_ca_eku_critical/) | `dating` | `w_sub_ca_eku_critical` — the three "optional extkeyUsage" sub-CA lints have no `IneffectiveDate`, and the clause they cite does not say what they say after BR 1.7.1 | Medium |
| [`ZT-075`](01-dating/ZT-075-w_dnsname_underscore_in_trd/) | `dating` | `w_dnsname_underscore_in_trd`'s `EffectiveDate` predates the requirement by over a decade | Medium |
| [`ZT-076`](01-dating/ZT-076-w_sub_cert_certificate_policies_marked_criti/) | `dating` | `w_sub_cert_certificate_policies_marked_critical` has no `IneffectiveDate`, understating severity after BR 2.0.0 | Medium |
| [`ZT-077`](01-dating/ZT-077-w_sub_cert_sha1_expiration_too_long/) | `dating` | `w_sub_cert_sha1_expiration_too_long` has no `IneffectiveDate`, double-reporting a MUST NOT violation as a SHOULD NOT | Medium |
| [`ZT-078`](01-dating/ZT-078-w_ct_sct_policy_count_unsatisfied/) | `dating` | `w_ct_sct_policy_count_unsatisfied` implements a superseded revision of the table it cites | Medium |
| [`ZT-079`](02-unreachable/ZT-079-w_ext_aia_access_location_missing/) | `unreachable` | `w_ext_aia_access_location_missing` cannot fire when `id-ad-caIssuers` names a non-URI location | High |
| [`ZT-080`](04-predicate/ZT-080-e_utf8_latin1_mixup/) | `predicate` | `e_utf8_latin1_mixup`'s table omits two manglings whose second character is invisible, and one of them is `à` | Medium |
| [`ZT-081`](04-predicate/ZT-081-an-IP-address-in-a-dNSName-is-reported-as-an/) | `predicate` | an IP address in a dNSName is reported as an invalid TLD | Low |
| [`ZT-082`](04-predicate/ZT-082-not-a-CA-certificate-is-used-to-mean-a-Subsc/) | `predicate` | "not a CA certificate" is used to mean "a Subscriber Certificate" | Medium |
| [`ZT-083`](04-predicate/ZT-083-e_dsa_shorter_than_2048_bits/) | `predicate` | `e_dsa_shorter_than_2048_bits` tests `N >= 244`, and 244 is 224 transposed | Medium |
| [`ZT-084`](04-predicate/ZT-084-e_crl_next_update_invalid/) | `predicate` | `e_crl_next_update_invalid` takes the CRL's population from a config flag, not from the CRL | Medium |
| [`ZT-085`](04-predicate/ZT-085-w_distribution_point_missing_ldap_or_uri/) | `predicate` | `w_distribution_point_missing_ldap_or_uri` fires when no `DistributionPointName` is present at all | Medium |
| [`ZT-086`](04-predicate/ZT-086-w_ext_cert_policy_explicit_text_includes_con/) | `predicate` | `w_ext_cert_policy_explicit_text_includes_control` only reads the `UTF8String` arm, so a CA evades it by choosing any other encoding | High |
| [`ZT-087`](04-predicate/ZT-087-w_ext_cert_policy_explicit_text_includes_con/) | `predicate` | `w_ext_cert_policy_explicit_text_includes_control` and `w_ext_cert_policy_explicit_text_not_utf8` are dated five years later than their own cited text | Medium |
| [`ZT-088`](04-predicate/ZT-088-n_ecdsa_ee_invalid_ku/) | `predicate` | `n_ecdsa_ee_invalid_ku` reports `encipherOnly`/`decipherOnly` as invalid even when RFC 5480 permits them | Low |
| [`ZT-089`](04-predicate/ZT-089-w_subject_contains_malformed_arpa_ip/) | `predicate` | `w_subject_contains_malformed_arpa_ip`'s `CheckApplies` reads the commonName; `Execute` does not | Low |
| [`ZT-090`](08-hygiene/ZT-090-w_sub_cert_aia_contains_internal_names/) | `hygiene` | `w_sub_cert_aia_contains_internal_names` cites a clause that says nothing about internal names | Low |
| [`ZT-091`](08-hygiene/ZT-091-w_ct_sct_policy_count_unsatisfied/) | `hygiene` | `w_ct_sct_policy_count_unsatisfied` is named `w_` and can only return a notice | Low |
| [`ZT-092`](08-hygiene/ZT-092-w_smime_aia_contains_internal_names/) | `hygiene` | `w_smime_aia_contains_internal_names` cites a clause that says nothing about internal names | Low |
| [`ZT-093`](08-hygiene/ZT-093-w_etsi_natural_person_key_usage_preferred_va/) | `hygiene` | `w_etsi_natural_person_key_usage_preferred_values` double-reports every invalid `keyUsage` alongside its own sibling | Low |
| [`ZT-094`](09-absent/ZT-094-BR-6.1.5-s-Subordinate-CA-column-is-a-disjun/) | `absent` | BR § 6.1.5's Subordinate CA column is a disjunction, and one branch of it is unlinted | Medium |

## Groups

### `00-already-filed` — Already on your issue tracker (9)

Someone filed each of these before we did. They are separated so the rest of the package is new information; what these add is a runnable case for a claim that is already yours. Each entry names the group it would otherwise sit in.

### `01-dating` — Requirements applied to certificates that predate them (22)

The largest group after the predicate bugs, and the one most often read as a scope decision rather than a defect. Three shapes: a check with the wrong effective date, a check with none at all for a dated requirement, and reference data — a TLD list, a set of reserved names — treated as though today's contents had always held.

The common cause is an assumption that the tool only ever sees recent issuance. Certificate Transparency holds twenty years of it, and root certificates in use today were issued before most of these requirements existed. A date too late suppresses real findings; too early reports certificates that were conformant when they were issued, which is the more common direction here.

### `02-unreachable` — Checks that cannot fire (6)

Registered, documented, and reports nothing — a tautological condition, an unreachable branch, a class never instantiated. These read as coverage from outside and are not.

### `03-scope` — Applied outside the population the clause governs (7)

The predicate is right and the population is wrong. Almost all of these are false positives against conformant certificates.

### `04-predicate` — The test itself is wrong (20)

Guard bugs, the wrong field read, an off-by-one, a walker that cannot express the shape it looks for. Mostly false negatives: the check passes the thing it is named for.

### `05-spec-reading` — Differing analysis of the normative text (4)

We read a clause differently. Filed as disagreements rather than defects, and the ones most likely to end with the maintainer telling us we are wrong.

### `06-parser` — Root cause in the decoder, not in the check (7)

The check asks a reasonable question and the decoder returns an answer that cannot carry the distinction. Fixing these inside a check is usually wrong; documenting the limit may be the better remedy.

### `07-robustness` — Panics, run-ending failures, and non-determinism (5)

Defects in how the tool runs rather than in what it decides. These reach every consumer whatever they lint.

### `08-hygiene` — Descriptions, citations, severities and tests (12)

Nothing here changes a verdict. Included because they mislead a reader, or because a test asserts less than it appears to.

### `09-absent` — A requirement no check covers (2)

Not a defect in an existing check. Recorded so the gap is visible.

