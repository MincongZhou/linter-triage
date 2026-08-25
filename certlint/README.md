# certlint — 39 confirmed defects

Reproduced against `certlint/certlint` at **528d78e**. Invocation: `cablint <cert.pem> | certlint <cert.der>`.

Numbered `CT-001`..`CT-039`, contiguous.

Your issue tracker was read on 2026-08-24 (8 issues, 5 open). Each entry says what it found.

| | group | what is wrong | today |
|---|---|---|---|
| [`CT-001`](00-already-filed/CT-001-the-TeletexString-repertoire-test-is-narrowe/) | `already-filed` | the `TeletexString` repertoire test is narrower than the type, DELETE included | Low |
| [`CT-002`](01-dating/CT-002-cablint-applies-BR-2.0-s-CDP-scheme-rule-to/) | `dating` | cablint applies BR 2.0's CDP scheme rule to pre-2.0 certificates | Medium |
| [`CT-003`](01-dating/CT-003-cablint-has-no-Baseline-Requirements-floor/) | `dating` | cablint has no Baseline Requirements floor | High |
| [`CT-004`](01-dating/CT-004-BR_2_0_0_EFFECTIVE-is-157-days-early/) | `dating` | `BR_2_0_0_EFFECTIVE` is 157 days early | Low |
| [`CT-005`](01-dating/CT-005-the-TLD-data-is-a-snapshot-of-today-so-a-wit/) | `dating` | the TLD data is a snapshot of today, so a withdrawn gTLD reads as never delegated | Medium |
| [`CT-006`](01-dating/CT-006-the-39-month-BR-ceiling-is-dated-15-months-t/) | `dating` | the 39-month BR ceiling is dated 15 months too early, ignoring a documented CA exception the same clause states | Medium |
| [`CT-007`](01-dating/CT-007-a-conforming-version-1-certificate-is-report/) | `dating` | a conforming version 1 certificate is reported as an error | Medium |
| [`CT-008`](02-unreachable/CT-008-UTCTime-without-seconds-cannot-fire-for-its/) | `unreachable` | `UTCTime without seconds` cannot fire for its own defect, and every firing is false | High |
| [`CT-009`](02-unreachable/CT-009-is-not-encoded-using-DER-can-never-fire-for/) | `unreachable` | `is not encoded using DER` can never fire for a name attribute or a policy qualifier | High |
| [`CT-010`](02-unreachable/CT-010-Missing-check-for-OtherName-can-never-be-emi/) | `unreachable` | `Missing check for OtherName …` can never be emitted | Low |
| [`CT-011`](02-unreachable/CT-011-dnsname-s-own-is_a-String-guard-can-never-be/) | `unreachable` | `dnsname`'s own `is_a? String` guard can never be reached | Low |
| [`CT-012`](02-unreachable/CT-012-is-using-deprecated-VideoexString-can-never/) | `unreachable` | `is using deprecated VideoexString` can never be emitted | Low |
| [`CT-013`](02-unreachable/CT-013-is-using-deprecated-GraphicString-can-never/) | `unreachable` | `is using deprecated GraphicString` can never be emitted | Low |
| [`CT-014`](02-unreachable/CT-014-is-using-deprecated-GeneralString-can-never/) | `unreachable` | `is using deprecated GeneralString` can never be emitted | Low |
| [`CT-015`](02-unreachable/CT-015-Unknown-type-of-TLD-can-never-be-emitted/) | `unreachable` | `Unknown type of TLD` can never be emitted | Low |
| [`CT-016`](02-unreachable/CT-016-E-No-PDU-defined/) | `unreachable` | `E: No PDU defined` cannot fire given certlint's own registered extension handlers | Low |
| [`CT-017`](04-predicate/CT-017-a-non-minimal-BIT-STRING-is-certified-as-DER/) | `predicate` | a non-minimal BIT STRING is certified as DER | High |
| [`CT-018`](04-predicate/CT-018-an-unknown-TLD-costs-the-wildcard-check-on-t/) | `predicate` | an unknown TLD costs the wildcard check on that name | Medium |
| [`CT-019`](04-predicate/CT-019-the-self-signed-CA-guard-reaches-two-AIA-bra/) | `predicate` | the self-signed-CA guard reaches two AIA branches of three | Medium |
| [`CT-020`](04-predicate/CT-020-the-Forum-s-reserved-policy-arc-selects-EV-a/) | `predicate` | the Forum's reserved policy arc selects EV and never excludes | Medium |
| [`CT-021`](04-predicate/CT-021-an-IP-address-in-a-dNSName-is-reported-as-an/) | `predicate` | an IP address in a dNSName is reported as an unknown TLD | Low |
| [`CT-022`](04-predicate/CT-022-certlint-requires-v3-of-every-certificate-wh/) | `predicate` | certlint requires v3 of every certificate, where RFC 5280 requires it only with extensions | Medium |
| [`CT-023`](04-predicate/CT-023-Generalized-Time-before-2050-has-no-lower-bo/) | `predicate` | `Generalized Time before 2050` has no lower bound, so it demands an impossible encoding | Low |
| [`CT-024`](04-predicate/CT-024-Unallowed-key-usage-for-public-key-names-a-k/) | `predicate` | `Unallowed key usage for … public key` names a key usage that does not exist | Low |
| [`CT-025`](04-predicate/CT-025-RFC822Name-has-empty-value-condemns-the-excl/) | `predicate` | `RFC822Name has empty value` condemns the excludedSubtree that excludes all email | Medium |
| [`CT-026`](04-predicate/CT-026-serial-number-entropy-is-split-by-signature/) | `predicate` | serial-number entropy is split by signature hash strength, a distinction the Baseline Requirements never made | Medium |
| [`CT-027`](04-predicate/CT-027-EV-identification-never-reads-the-disclosed/) | `predicate` | EV identification never reads the disclosed CA-specific policy arcs, only the reserved one | High |
| [`CT-028`](04-predicate/CT-028-the-serverAuth-warning-fires-for-the-wrong-r/) | `predicate` | the serverAuth warning fires for the wrong reason on almost every certificate it names, and folds in a second misclassification | Medium |
| [`CT-029`](04-predicate/CT-029-Duplicate-SAN-entry-compares-across-GeneralN/) | `predicate` | `Duplicate SAN entry` compares across `GeneralName` types | Medium |
| [`CT-030`](04-predicate/CT-030-a-control-character-in-an-IA5String-is-repor/) | `predicate` | a control character in an `IA5String` is reported as an error, and `IA5String` admits them | Low |
| [`CT-031`](04-predicate/CT-031-the-EC-key-error-message-describes-the-strin/) | `predicate` | the EC key error message describes the string, not the key | Low |
| [`CT-032`](04-predicate/CT-032-the-example-domain-test-is-anchored-at-the-w/) | `predicate` | the example-domain test is anchored at the wrong end | Medium |
| [`CT-033`](04-predicate/CT-033-DSA-keyUsage-uses-one-allow-list-for-every-r/) | `predicate` | DSA `keyUsage` uses one allow-list for every role | Medium |
| [`CT-034`](04-predicate/CT-034-policy-qualifier-identity-is-over-severed-as/) | `predicate` | policy qualifier identity is over-severed as an error | Medium |
| [`CT-035`](07-robustness/CT-035-an-EC-point-at-infinity-segfaults-the-interp/) | `robustness` | an EC point at infinity segfaults the interpreter | High |
| [`CT-036`](08-hygiene/CT-036-commonNames-in-BR-certificate-contains-U-lab/) | `hygiene` | `commonNames in BR certificate contains U-labels` is a Warning where BR § 7.1.4.3 states a MUST | Medium |
| [`CT-037`](08-hygiene/CT-037-EC-encipherOnly-and-decipherOnly-both-set-ci/) | `hygiene` | EC "encipherOnly and decipherOnly both set" cites nothing | Medium |
| [`CT-038`](08-hygiene/CT-038-SCT-list-criticality-cites-nothing/) | `hygiene` | SCT list criticality cites nothing | Medium |
| [`CT-039`](09-absent/CT-039-BR-7.1.4.3-s-character-for-character-clause/) | `absent` | BR § 7.1.4.3's character-for-character clause has no message | Medium |

## Groups

### `00-already-filed` — Already on your issue tracker (1)

Someone filed each of these before we did. They are separated so the rest of the package is new information; what these add is a runnable case for a claim that is already yours. Each entry names the group it would otherwise sit in.

### `01-dating` — Requirements applied to certificates that predate them (6)

The largest group after the predicate bugs, and the one most often read as a scope decision rather than a defect. Three shapes: a check with the wrong effective date, a check with none at all for a dated requirement, and reference data — a TLD list, a set of reserved names — treated as though today's contents had always held.

The common cause is an assumption that the tool only ever sees recent issuance. Certificate Transparency holds twenty years of it, and root certificates in use today were issued before most of these requirements existed. A date too late suppresses real findings; too early reports certificates that were conformant when they were issued, which is the more common direction here.

### `02-unreachable` — Checks that cannot fire (9)

Registered, documented, and reports nothing — a tautological condition, an unreachable branch, a class never instantiated. These read as coverage from outside and are not.

### `04-predicate` — The test itself is wrong (18)

Guard bugs, the wrong field read, an off-by-one, a walker that cannot express the shape it looks for. Mostly false negatives: the check passes the thing it is named for.

### `07-robustness` — Panics, run-ending failures, and non-determinism (1)

Defects in how the tool runs rather than in what it decides. These reach every consumer whatever they lint.

### `08-hygiene` — Descriptions, citations, severities and tests (3)

Nothing here changes a verdict. Included because they mislead a reader, or because a test asserts less than it appears to.

### `09-absent` — A requirement no check covers (1)

Not a defect in an existing check. Recorded so the gap is visible.

