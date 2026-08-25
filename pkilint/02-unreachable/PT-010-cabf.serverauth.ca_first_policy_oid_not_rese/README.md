# PT-010 — the first-policy-OID recommendation is unreachable on a certificate that

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

- **#122** — cabf.serverauth.ca_multiple_reserved_policy_oids duplicated *(closed)*
  **related.** #122 reports the finding code appearing on two rows of finding_metadata.csv with different citations. Same code, different claim.
- **#28** — False positive: dNSName type in SAN entry of clientAuth certs *(closed)*
  **related.** As PT-024.

## Analysis

also has too many reserved identifiers**

`CaCertificatePoliciesValidator.validate` tests, in order: `anyPolicy`
present; then, for a policy-restricted certificate, whether a reserved OID is
present at all (`VALIDATION_NO_RESERVED_OID`); then whether more than one is
present (`VALIDATION_MULTIPLE_RESERVED_OIDS`); then, as the last statement in
the function, whether the first is reserved
(`VALIDATION_FIRST_OID_NOT_RESERVED`). Each `raise` is a Python exception —
control leaves `validate` at the first one reached, so a certificate that
trips the multiple-reserved-OIDs branch never reaches the first-OID branch,
even when the certificate's own `certificatePolicies` also breaches it.

BR § 7.1.2.10.5 states the count requirement (MUST contain exactly one) and
the ordering recommendation (RECOMMENDS listing it first) as two independent
sentences about the same extension. A certificate that fails the first can
still independently fail the second, and the clause gives no reason to treat
one as canceling the other — "regardless of order" in the MUST sentence, if
anything, keeps the two questions separate.

**Reproduced on a certificate from Mozilla CA incident [bug
1963663](https://bugzilla.mozilla.org/show_bug.cgi?id=1963663).** Its
`certificatePolicies` asserts, in encounter order: `1.2.250.1.177.2.0.1.1` (a
French RGS private arc), then the EV, DV and OV reserved identifiers. pkilint
0.13.3, `--detect`:

```
cabf.serverauth.ca_multiple_reserved_policy_oids (ERROR): Multiple reserved policy OIDs present: 2.23.140.1.1, 2.23.140.1.2.1, 2.23.140.1.2.2
```

— and nothing about the first OID, though `1.2.250.1.177.2.0.1.1` is plainly
not reserved and the certificate's own type (`INTERNAL-UNCONSTRAINED-TLS-CA`)
is one the check applies to. **Observed**: `ca_first_policy_oid_not_reserved`
absent.

```json
{"lint_id": "w_ca_first_policy_oid_not_reserved", "details": "certificatePolicies asserts a reserved identifier, but the first PolicyInformation value is 1.2.250.1.177.2.0.1.1"}
```

**Fix.** Collect all four findings for one `PolicyInformation` set before
raising, or restructure the four conditions as independent checks rather than
a chain of `raise` statements sharing one `validate` call.
