# ZT-085 — `w_distribution_point_missing_ldap_or_uri` fires when no `DistributionPointName` is present at all

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | reproduced against **zlint's own test fixtures** |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

The clause, again: "When present, DistributionPointName SHOULD include at
least one LDAP or HTTP URI." The check's `CheckApplies` gates only on the
extension being present:

```go
func (l *distribNoLDAPorURI) CheckApplies(c *x509.Certificate) bool {
	return util.IsExtInCert(c, util.CrlDistOID)
}
```

— never asking whether any `DistributionPoint` in the extension actually
carries a `distributionPoint` field (and therefore a `DistributionPointName`)
at all. RFC 5280 §4.2.1.13 permits a `DistributionPoint` naming only
`cRLIssuer`, with no `distributionPoint` field, and a `SEQUENCE SIZE (1..MAX)
OF DistributionPoint` that happens to decode as empty carries no
`DistributionPointName` either. In both shapes the clause's own "when present"
condition is never met, so the SHOULD does not bind — but the check fires
anyway, because `zcrypto`'s `CRLDistributionPoints` field (which `Execute`'s
search loop reads) is empty either way, and empty reads as "no URI found"
rather than "nothing to ask the question of".

**observed**, on two of zlint's own fixtures:

```
$ zlint -includeNames w_distribution_point_missing_ldap_or_uri empty_seq_of_cdp.pem
{"w_distribution_point_missing_ldap_or_uri":{"result":"warn"}}
```

`empty_seq_of_cdp.pem`'s `cRLDistributionPoints` is a bare empty SEQUENCE — no
`DistributionPoint` at all:

```
X509v3 CRL Distribution Points:

```

```
$ zlint -includeNames w_distribution_point_missing_ldap_or_uri,e_missing_crl_distrib_point crlIncomlepteDp.pem
{"e_missing_crl_distrib_point":{"result":"NA"},"w_distribution_point_missing_ldap_or_uri":{"result":"warn"}}
```

`crlIncomlepteDp.pem`'s one `DistributionPoint` states only `reasons` — which
RFC 5280 §4.2.1.13 forbids outright ("a DistributionPoint MUST NOT consist of
only the reasons field") — with no `distributionPoint` and no `cRLIssuer`
field either:

```
X509v3 CRL Distribution Points:
    Reasons:
      Key Compromise, CA Compromise, Affiliation Changed, Cessation Of Operation

```

Tellingly, zlint's own **sibling** check `e_missing_crl_distrib_point`
correctly reads this certificate as having no usable CRL distribution point
(`NA`) — the inconsistency is between two zlint checks reading the same
extension, not a case of this lane's reasoning drifting from zlint's.

**correct**: `NA` on both — no `DistributionPointName` exists anywhere in
either extension for the SHOULD to address.

**mechanism**: same shape as ZT-079 — `CheckApplies` is gated on a coarser
predicate (extension presence) than the clause's own condition
(`DistributionPointName` presence), and the two coincide everywhere except the
shapes RFC 5280 itself explicitly permits: `cRLIssuer`-only, and
(structurally, if unusually) an empty `DistributionPoint` sequence.

**fix**: gate applicability on "at least one `DistributionPoint` carries a
`distributionPoint` field", read before filtering that field's `GeneralName`
alternatives down to URIs.

See that rule's `REASONING.md`, written before this reproduction landed and
updated to point at it.

## What was not verified
