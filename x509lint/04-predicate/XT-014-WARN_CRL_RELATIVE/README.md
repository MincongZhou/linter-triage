# XT-014 — `WARN_CRL_RELATIVE` fires on a `DistributionPoint` that never chose the relative-name alternative

| | |
|---|---|
| **Tool** | `kroeckx/x509lint` at `103c92f` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | `x509lint 103c92f`, reproduced both on a fabricated pair and on the real certificate |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```
$ x509lint comsign-intermediate.pem      # converted from
                                          # 
E: CRL DistributionPoint's cRLIssuer not a directoryName
E: CA certificate with non-critical Basic Constraints
E: AKID without a key identifier
W: CRL distribution point uses relative name    <- observed; no relative name is used
I: Checking as intermediate CA certificate
```

The certificate's own `openssl x509 -text` output for the extension:

```
X509v3 CRL Distribution Points:
    CRL Issuer:
      URI:http://fedir.comsign.co.il/crl/ComSignSecuredCA.crl
    CRL Issuer:
      URI:http://crl1.comsign.co.il/crl/ComSignSecuredCA.crl
```

Two `DistributionPoint`s, each naming only `cRLIssuer` — no
`distributionPoint` field at all, which RFC 5280 § 4.2.1.13 explicitly permits
("each of these fields is optional"; a `cRLIssuer`-only point is the example
the clause itself uses to justify making `distributionPoint` optional).
Neither point selects `nameRelativeToCRLIssuer`.

**mechanism**: `CheckCRL` (`checks.c:1236`) reads:

```c
if (dp->distpoint != NULL && dp->distpoint->type == 0)
{
    /* full name */
    ...
}
else
{
    /* relative name */
    SetWarning(WARN_CRL_RELATIVE);
    ...
}
```

The `else` arm fires whenever `dp->distpoint` is `NULL` — no
`distributionPoint` field present — as well as when it is non-`NULL` and
selects the relative-name CHOICE arm (`type == 1`). The message
(`messages.c:165`, "CRL distribution point uses relative name") and its own
citation both describe only the second case. Executed against a minimal
fabricated certificate carrying a single `DistributionPoint` with only
`cRLIssuer` (no `distributionPoint` field, no relative name): x509lint reports
`WARN_CRL_RELATIVE` on it.

**observed**: the warning fires on the ComSign certificate above. **correct**:
no finding — the certificate uses neither `distributionPoint` alternative on
either point, so RFC 5280's "SHOULD NOT use nameRelativeToCRLIssuer" has
nothing to be violated by.

**fix**: gate on `dp->distpoint != NULL && dp->distpoint->type == 1`
(explicitly the relative-name alternative), and treat `dp->distpoint == NULL`
as inapplicable rather than folding it into the `else` arm.

Executed and found not to be a gap: `CheckBitString(dp->reasons)` runs
unconditionally before the reasons- specific checks and reports the generic
`ERR_BIT_STRING_LEADING_0` ("Bit string with leading 0") for exactly this
shape, on any `BIT STRING` x509lint examines.
