# XT-012 — `ERR_POLICY_BR` tests two of the four reserved identifiers it names

| | |
|---|---|
| **Tool** | `kroeckx/x509lint` at `103c92f` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | reproduced on a fabricated pair, corroborated on real issuance from three Mozilla CA compliance bugs |

## Upstream issues, adjudicated

- **#35** — id-kp-clientAuth certificates incorrectly trigger ERR_POLICY_BR  *(closed)*
  **related.** Same lint, ERR_POLICY_BR. #35 is about which certificates it applies to; this entry is about which of the four reserved identifiers it tests.

## Analysis

```
$ x509lint XL-T-x5-a-02-ov-policy-clientauth.pem   # 2.23.140.1.2.2, eku = clientAuth
(no ERR_POLICY_BR)                                  <- observed

$ x509lint XL-T-x5-a-02-dv-policy-clientauth.pem   # 2.23.140.1.2.1, otherwise identical
E: Baseline Requirements policy present for non server authentication certificate
```

**observed**: silence on the organization-validated and extended-validation
reserved identifiers. **correct**: the same error. `2.23.140.1.2.2` and
`2.23.140.1.1` are Baseline Requirements reserved policy identifiers exactly
as `2.23.140.1.2.1` and `2.23.140.1.2.3` are (BR § 7.1.6.1), and the message
names *"Baseline Requirements policy"* without qualification.

```c
if (DomainValidated || IndividualValidated || CabIVPresent)
{
    SetError(ERR_POLICY_BR);
}
```

`OrganizationValidated` (set at `checks.c:761`) and `EVValidated` (set at
`checks.c:808`) are absent. Both flags exist, both are set in the same loop
from the same comparison shape, and the `INF_UNKNOWN_VALIDATION` test twelve
lines later (`checks.c:912`) names all four. Only this test names two.

**Caveat on the fix**, which the maintainer will already have in mind: all
three flags are set by lists mixing the CA/Browser Forum reserved arcs with
CA-proprietary identifiers, several of which are legitimately used outside
TLS. If that is why OV and EV were left out, the narrow fix is to test the
four reserved arcs alone at this site and leave the proprietary lists to the
subject-profile checks that need them.

## Refuted, and recorded so it is not rediscovered

**`ERR_INVALID_TYPE_USER_NOTICE` (`checks.c:865`) can never fire, and that is
not a defect in x509lint.**

```c
if (s->type != V_ASN1_UTF8STRING && s->type != V_ASN1_BMPSTRING &&
    s->type != V_ASN1_VISIBLESTRING && s->type != V_ASN1_IA5STRING)
{
    SetError(ERR_INVALID_TYPE_USER_NOTICE);
}
```

So `s->type` at `checks.c:865` is always one of the four, the condition is
always false, and the site is defensive belt-and-braces after a parser that
has already made the guarantee. It is not a gap in x509lint and not a gap in
the port.

**Two further differences investigated and found to be existing entries, not
new ones.** `ERR_POLICY_BR` on a delegated OCSP responder asserting a reserved
identifier is `XT-006`'s ground. Neither is re-filed here.
