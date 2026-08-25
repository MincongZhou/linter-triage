# ZT-070 — `w_ext_policy_map_not_critical`'s effective date reports certificates that were compliant when issued

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | reproduced against a real, currently-trusted root certificate |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```go
/**********************************************************
RFC 5280: 4.2.1.5.  Policy Mappings
This extension MAY be supported by CAs and/or applications.
   Conforming CAs SHOULD mark this extension as critical.
**********************************************************/
...
EffectiveDate: util.RFC2459Date,   // 1999-01-01
```

**RFC 2459 §4.2.1.6 — the document the lint's own `EffectiveDate` constant is
named for — states the *opposite* requirement for the same extension:**

> This extension may be supported by CAs and/or applications, and it MUST be
> non-critical.

A certificate issued while RFC 2459 governed and correctly following it —
`policyMappings` present, marked non-critical, as its own document required at
the time — is not a certificate that ever breached a SHOULD-be-critical
clause, because no such clause existed until RFC 5280 superseded RFC 2459 nine
years later. Dating the check to `RFC2459Date` reports conformant 1999–2008
issuance as a defect.

```
$ zlint -includeNames w_ext_policy_map_not_critical root-21db20123660bb2e.pem
{"w_ext_policy_map_not_critical":{"result":"warn"}}
```

**correct**: no finding (`NE`/pass). The certificate's `notBefore` predates
RFC 5280's 2008-05-01 effective date by nearly three years; RFC 2459, the
document actually governing this certificate's issuance, required the opposite
of what the check demands.

**mechanism**: `EffectiveDate: util.RFC2459Date` is the wrong document's date
for this clause specifically. It is the right date for five of this lane's
seven sibling criticality checks (`w_ext_key_usage_not_critical`,
`w_ext_crl_distribution_marked_critical`, `w_ext_ian_critical`, and the
`w_ext_subject_key_identifier_missing_sub_cert` SHOULD), each of which states
the identical sentence in both RFC 2459 and RFC 5280 — confirmed by reading
both documents directly rather than assuming continuity.

**fix**: date the check no earlier than RFC 5280's own effective date,
2008-05-01 (`util.RFC5280Date`). Whichever it is, `RFC2459Date` is not.

See that rule's `REASONING.md` for the full RFC 2459-versus-RFC 5280
comparison.
