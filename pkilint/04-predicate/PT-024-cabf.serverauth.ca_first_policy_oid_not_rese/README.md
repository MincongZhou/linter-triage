# PT-024 — the first-policy-OID recommendation fires on certificates with no reserved

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

- **#28** — False positive: dNSName type in SAN entry of clientAuth certs *(closed)*
  **follow-up.** Closed by exempting non-TLS CAs from ca_first_policy_oid_not_reserved. This entry is about the population the fix left.

## Analysis

BR § 7.1.2.10.5 (CA) and § 7.1.2.7.9 (subscriber) each read: "This Profile
RECOMMENDS that the first `PolicyInformation` value … contains the Reserved
Certificate Policy Identifier … Regardless of the order …, the Certificate
Policies extension MUST contain exactly one Reserved Certificate Policy
Identifier." Two clauses in one sentence: a MUST about *how many* reserved
identifiers are present, and a RECOMMENDS about *where* one sits, conditioned
on one being present at all.

`CaCertificatePoliciesValidator.validate` (`serverauth_ca.py`) reads:

```python
if (
    self._certificate_type
    != serverauth_constants.CertificateType.NON_TLS_CA
    and policy_oids[0]
    not in serverauth_constants.SERVERAUTH_RESERVED_POLICY_OIDS
):
    raise validation.ValidationFindingEncountered(
        self.VALIDATION_FIRST_OID_NOT_RESERVED
    )
```

No guard on `any(reserved_oids)`. `SubscriberPoliciesValidator.validate`
(`serverauth_subscriber.py`) has the identical shape. A certificate asserting
*no* reserved identifier at all has a `policy_oids[0]` that is trivially not
reserved, so the code fires the recommendation beside
`ca_missing_reserved_policy_oid` / `subscriber_missing_reserved_policy_oid` on
the same certificate for the same absence — reported as a second, independent
defect when there is nothing yet to put in order.

**The mechanism, established by executing it.** `python3 -c` against a
`PolicyInformation` list holding one private, non-reserved arc:

```python
>>> policy_oids = ["1.3.6.1.4.1.99999.1"]
>>> policy_oids[0] not in SERVERAUTH_RESERVED_POLICY_OIDS
True
```

confirms the branch is entered whether or not any element of `policy_oids` is
reserved — the predicate reads only the first element's membership, never the
set's.

**Fix.** Add `and any(reserved_oids)` (or equivalent) to both conditions.
