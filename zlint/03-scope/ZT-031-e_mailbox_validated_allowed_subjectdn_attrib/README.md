# ZT-031 — `e_mailbox_validated_allowed_subjectdn_attributes` judges CA certificates against a subscriber table

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `03-scope` — Applied outside the population the clause governs |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | a real Subordinate CA from the CCADB trust store, and one of zlint's own subscriber fixtures as the control |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```go
Citation:      S/MIME BRs: 7.1.4.2.3
CheckApplies:  return util.IsMailboxValidatedCertificate(c)
```

S/MIME BR §7.1.4.2 is headed **"Subject information ‑ subscriber
certificates"**, and §7.1.4.2.3 is one of its four profile tables. It marks
`organizationName` SHALL NOT. The lint's `CheckApplies` tests the policy
identifier and not the role, so a Subordinate CA asserting a mailbox-validated
identifier is judged against the Subscriber table — and every CA has an
`organizationName`.

**zlint's own sibling on the identical clause gets it right.** Two lints read
one table:

| file | `CheckApplies` |
|---|---|
| `mailbox_validated_enforce_subject_field_restrictions.go` | `IsMailboxValidatedCertificate(c) && IsSubscriberCert(c)` |
| `lint_e_mailbox_validated_allowed_subjectdn_attributes.go` | `IsMailboxValidatedCertificate(c)` |

Same document, same section, same table, one role test. `lint_commonname_
mailbox_validated.go` and `lint_org_validated_invalid_cn.go` carry the role
test too, so this is a slip and not a reading — *two of anything is a design;
one is a slip*, and here three of four are the design.

The reproduction runs both lints over one certificate and prints `NA` from the
scoped one beside `error` from this one, with a subscriber control that both
report.

**Medium.** It reports conformant issuance as misissuance, and zlint's results
are ground truth other tools consume. Not High: nothing is suppressed and the
sibling still answers every certificate the section addresses.

Fix: `CheckApplies` → `IsMailboxValidatedCertificate(c) &&
util.IsSubscriberCert(c)`. The wider question is whether both lints should
exist at all, since they cite one section and read one table.

**Three neighbours are worth the same look and are not claimed here.**
`lint_invalid_individual_identity.go`,
`lint_registration_scheme_id_matches_subject_country.go` and
`lint_subject_country_name.go` also read §7.1.4.2.x tables and also omit
`IsSubscriberCert`. Whether that is the same defect depends on each clause,
and none of the three fires on a CA certificate — so there is nothing to
reproduce and the claim is not made.
