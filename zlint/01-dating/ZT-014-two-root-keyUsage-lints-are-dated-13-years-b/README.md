# ZT-014 — two root keyUsage lints are dated 13 years before the document they cite

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | three real trust-store roots |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

Observed `error` on a root issued 2003-02-07; correct `NE`.

```go
// lint_root_ca_key_usage_must_be_critical.go, and
// lint_root_ca_key_usage_present.go, identically
Citation:      "BRs: 7.1.2.1",
Source:        lint.CABFBaselineRequirements,
EffectiveDate: util.RFC2459Date,          // 1999-01-01
```

`lint/base.go` states what the field does: "Lints automatically returns NE for
all certificates where CheckApplies is true but with NotBefore <
EffectiveDate." The Baseline Requirements take effect on 2012-07-01, which is
`util.CABEffectiveDate`, and what 75 other lints in `cabf_br/` use.

The criticality lint is the substantive half. BR §7.1.2.1(b) — "This extension
MUST be present and MUST be marked critical", verified present in BR 1.1.6 and
unchanged through 1.8.7 — is a CA/Browser Forum MUST. RFC 5280 §4.2.1.3, and
RFC 2459 §4.2.1.3 before it, says only "Conforming CAs SHOULD mark this
extension as critical". So every firing on a root issued before 2012-07-01
reports an RFC SHOULD as a BR error, thirteen and a half years before the
document that made it a MUST.

The presence lint was recorded here as the citation half alone, on the grounds
that "RFC 2459 §4.2.1.3 does require the extension of a certificate whose key
validates certificate signatures, so 1999 suits the requirement".

> When used, this extension SHOULD be marked critical.

There is no presence requirement in it at all. The obligation arrives with RFC
3280 and survives into RFC 5280 §4.2.1.3 as "Conforming CAs MUST include this
extension in certificates that contain public keys that are used to validate
digital signatures on other public key certificates or CRLs."

So the presence lint's *date* is wrong as well as its citation, by three years
and three months, and zlint settles the point against itself: the sibling
`lint_ca_key_usage_missing.go` asks the same presence question of the same
extension, cites "BRs: 7.1.2.1, RFC 5280: 4.2.1.3", and dates itself
`util.RFC3280Date`. One lint on each date for one requirement is not a design.

**Fix, revised:** `EffectiveDate: util.RFC3280Date` on the presence lint, not
merely a citation repair. Twelve trust-store roots issued 1999–2001 are
faulted by it against a requirement that did not exist when they were issued.

The original carve-out is left visible rather than deleted. It was written
from the clause the reader expected to find rather than the clause that is
there, which is the failure mode this archive exists to catch, and it survived
being recorded as **Confirmed**.

| lint | firings | on roots issued before 2012-07-01 |
|---|---|---|
| `e_root_ca_key_usage_must_be_critical` | 93 | 73, of which 68 trust-store roots |
| `e_root_ca_key_usage_present` | 36 | 29, of which 23 trust-store roots |

The criticality firings span 1999 (13), 2000 (4), 2001 (9), 2002 (5), 2003
(4), 2004 (6), 2005 (7), 2006 (6), 2007 (6), 2008 (2), 2009 (2), 2010 (2),
2011 (5) and two in 2012 before the date.

Lints dated `util.ZeroDate` are excluded from that sweep throughout. zlint
treats a zero date as no lower bound rather than as a date in year zero, so a
lint declaring it makes no dating claim to contradict — 17 CABF-sourced lints
would otherwise have been counted, wrongly.

Fix: `EffectiveDate: util.CABEffectiveDate` on both. For the presence lint the
alternative is to keep the date and add RFC 5280 §4.2.1.3 to the Citation, as
`lint_ca_key_usage_missing.go` already does.
