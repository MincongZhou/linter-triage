# x509lint — 21 confirmed defects

Reproduced against `kroeckx/x509lint` at **103c92f**. Invocation: `x509lint <cert.pem>`.

Numbered `XT-001`..`XT-021`, contiguous.

Your issue tracker was read on 2026-08-24 (12 issues, 1 open). Each entry says what it found.

| | group | what is wrong | today |
|---|---|---|---|
| [`XT-001`](00-already-filed/XT-001-ERR_SAN_TYPE/) | `already-filed` | `ERR_SAN_TYPE`'s name-type table is never scoped by certificate type, so it fires on CA certificates a subscriber-only clause does not govern | Medium |
| [`XT-002`](02-unreachable/XT-002-a-CA-certificate-that-omits-keyCertSign-is-c/) | `unreachable` | a CA certificate that omits `keyCertSign` is checked as a leaf, and the check for that omission cannot fire | High |
| [`XT-003`](02-unreachable/XT-003-ERR_GEN_NAME_TYPE/) | `unreachable` | `ERR_GEN_NAME_TYPE` is unreachable: OpenSSL's own decoder fixes the field it tests | High |
| [`XT-004`](02-unreachable/XT-004-ERR_INVALID_GENERAL_NAME_TYPE/) | `unreachable` | `ERR_INVALID_GENERAL_NAME_TYPE` is unreachable for the same reason, one level up | High |
| [`XT-005`](02-unreachable/XT-005-CheckTime/) | `unreachable` | `CheckTime`'s two EV limbs are dead code: the EV flag is set 73 lines of call sequence after it is read | Medium |
| [`XT-006`](03-scope/XT-006-the-TLS-subscriber-profile-is-applied-to-del/) | `scope` | the TLS subscriber profile is applied to delegated OCSP responders | Medium |
| [`XT-007`](03-scope/XT-007-ERR_NAME_NO_IV_POLICY/) | `scope` | `ERR_NAME_NO_IV_POLICY` is applied to CA certificates, where the identifier that switches it off is never recorded | Medium |
| [`XT-008`](04-predicate/XT-008-an-unrecognised-EKU-switches-off-four-SAN-na/) | `predicate` | an unrecognised EKU switches off four SAN name-type prohibitions | High |
| [`XT-009`](04-predicate/XT-009-ERR_UNKNOWN_SIGNATURE_ALGORITHM/) | `predicate` | `ERR_UNKNOWN_SIGNATURE_ALGORITHM` — `Unkonwn signature algorithm` | Low |
| [`XT-010`](04-predicate/XT-010-a-duplicated-extension-is-reported-as-an-abs/) | `predicate` | a duplicated extension is reported as an absent one | Medium |
| [`XT-011`](04-predicate/XT-011-the-RSASSA-PSS-salt-length-check-is-inverted/) | `predicate` | the RSASSA-PSS salt-length check is inverted for SHA-384 and SHA-512 | High |
| [`XT-012`](04-predicate/XT-012-ERR_POLICY_BR/) | `predicate` | `ERR_POLICY_BR` tests two of the four reserved identifiers it names | Medium |
| [`XT-013`](04-predicate/XT-013-CheckSigAlg/) | `predicate` | `CheckSigAlg` — the second RSASSA-PSS parameter parse reads the tbsCertificate's bytes with the outer identifier's length | Low |
| [`XT-014`](04-predicate/XT-014-WARN_CRL_RELATIVE/) | `predicate` | `WARN_CRL_RELATIVE` fires on a `DistributionPoint` that never chose the relative-name alternative | Medium |
| [`XT-015`](04-predicate/XT-015-ERR_KEY_USAGE_UNKNOWN_BIT/) | `predicate` | `ERR_KEY_USAGE_UNKNOWN_BIT` reads only the first two content octets, so a `keyUsage` longer than that never draws it | Low |
| [`XT-016`](04-predicate/XT-016-ERR_KEY_USAGE_HAS_CERT_SIGN/) | `predicate` | `ERR_KEY_USAGE_HAS_CERT_SIGN` — the certificate type is inferred from state a defect can change | Medium |
| [`XT-017`](04-predicate/XT-017-ERR_CN_NOT_IN_SAN/) | `predicate` | `ERR_CN_NOT_IN_SAN` has been commented out since 2016 | High |
| [`XT-018`](04-predicate/XT-018-CheckStringValid/) | `predicate` | `CheckStringValid` — a comment marking a branch "shouldn't happen" is wrong, reachable via a `UTF8String` glibc's own `iconv` misjudges | Low |
| [`XT-019`](04-predicate/XT-019-ERR_CA_CERT_NOT_CA/) | `predicate` | `ERR_CA_CERT_NOT_CA` has no reachable input | Medium |
| [`XT-020`](04-predicate/XT-020-the-demotion-is-EXFLAG_INVALID-not-an-uncach/) | `predicate` | the demotion is `EXFLAG_INVALID`, not an uncached `EXFLAG_CA`; one content octet in *any* extension re-profiles a root as a leaf | Medium |
| [`XT-021`](05-spec-reading/XT-021-WARN_NO_EKU/) | `spec-reading` | `WARN_NO_EKU` reports a real MUST as an unconditional warning | Medium |

## Groups

### `00-already-filed` — Already on your issue tracker (1)

Someone filed each of these before we did. They are separated so the rest of the package is new information; what these add is a runnable case for a claim that is already yours. Each entry names the group it would otherwise sit in.

### `02-unreachable` — Checks that cannot fire (4)

Registered, documented, and reports nothing — a tautological condition, an unreachable branch, a class never instantiated. These read as coverage from outside and are not.

### `03-scope` — Applied outside the population the clause governs (2)

The predicate is right and the population is wrong. Almost all of these are false positives against conformant certificates.

### `04-predicate` — The test itself is wrong (13)

Guard bugs, the wrong field read, an off-by-one, a walker that cannot express the shape it looks for. Mostly false negatives: the check passes the thing it is named for.

### `05-spec-reading` — Differing analysis of the normative text (1)

We read a clause differently. Filed as disagreements rather than defects, and the ones most likely to end with the maintainer telling us we are wrong.

