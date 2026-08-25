# XT-007 — `ERR_NAME_NO_IV_POLICY` is applied to CA certificates, where the identifier that switches it off is never recorded

| | |
|---|---|
| **Tool** | `kroeckx/x509lint` at `103c92f` |
| **Group** | `03-scope` — Applied outside the population the clause governs |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | reproduced on zlint's own fixtures and on a fabricated pair |

## Upstream issues, adjudicated

- **#35** — id-kp-clientAuth certificates incorrectly trigger ERR_POLICY_BR  *(closed)*
  **related.** As XT-006; this entry is ERR_NAME_NO_IV_POLICY on CA certificates.

## Analysis

```
$ x509lint XL-T-x5-a-01-ca-with-iv-policy.pem   # CA:TRUE, keyCertSign+cRLSign,
                                                # SN=Washington GN=Alexander,
                                                # certificatePolicies = 2.23.140.1.2.3
E: Subject with givenName or surname but without the CAB IV policy oid   <- observed
E: AKID missing
E: SKID missing
I: Checking as intermediate CA certificate

$ x509lint XL-T-x5-a-01-subscriber-with-iv-policy.pem   # same subject, same policy,
                                                        # basicConstraints CA:FALSE
(no such error)
```

The certificate asserts exactly the identifier the message asks for and is
reported anyway.

**observed**: `ERR_NAME_NO_IV_POLICY` on a CA certificate asserting
`2.23.140.1.2.3`. **correct**: no finding. The clause the site itself cites —
the comment reads `/* Required by CAB 7.1.4.2.2c */` — sits under BR §
7.1.4.2, *Subject Information – Subscriber Certificates*. A CA certificate's
subject is profiled by § 7.1.4.3, which states no such requirement. And even
granting the tool wants the check on CA certificates, a CA certificate cannot
satisfy it.

**This is not `XT-002`.** The subject certificate asserts `keyCertSign` and
`cRLSign`, and `GetType` types it *"intermediate CA certificate"* — correctly.
The defect is in `CheckPolicy`'s own scoping, not in the typing.

**mechanism** — `checks.c:888`, outside the `type == SubscriberCertificate`
guard that encloses the rest of the policy work:

```c
if (GetBit(cert_info, CERT_INFO_SERV_AUTH) || CERT_INFO_ANY_EKU || CERT_INFO_NO_EKU)
{
    if ((IsNameObjPresent(subject, obj_givenName) || IsNameObjPresent(subject, obj_surname))
        && !CabIVPresent)
    {
        /* Required by CAB 7.1.4.2.2c */
        SetError(ERR_NAME_NO_IV_POLICY);
    }
}
```

`CabIVPresent` is set at `checks.c:776`, inside `if (type ==
SubscriberCertificate)`. On any certificate `GetType` does not call a
Subscriber Certificate the flag is false whatever the certificate asserts, so
`&& !CabIVPresent` is always true and the escape hatch the check names is
unreachable on the population the check is being applied to. A CA certificate
with no `extendedKeyUsage` at all reaches the block through the
`CERT_INFO_NO_EKU` limb, which is the common shape.

Beside it, `CabIVPresent` (`checks.c:776`) and `IndividualValidated` (`checks.c:781`) are set under two textually identical `strcmp` guards four lines apart, so the `IndividualValidated || CabIVPresent` disjunction at `checks.c:899` can never distinguish anything. That is not a defect on its own; it is where a reader looking for the intended scoping will end up.

**fix**: guard the block on the profile it cites — `if (type == SubscriberCertificate && (GetBit(cert_info, CERT_INFO_SERV_AUTH) || …))`.
