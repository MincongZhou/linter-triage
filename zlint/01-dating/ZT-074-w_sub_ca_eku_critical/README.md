# ZT-074 — the three "optional extkeyUsage" sub-CA lints have no `IneffectiveDate`, and the clause they cite does not say what they say after BR 1.7.1

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | document-and-source reproduction, three lints |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

`w_sub_ca_eku_critical`, `n_sub_ca_eku_missing` and
`n_sub_ca_eku_not_technically_constrained` all cite BR §7.1.2.2g / §7.1.5 and
carry either no `EffectiveDate` at all (`n_sub_ca_eku_missing`:
`util.CABEffectiveDate`, i.e. 2012-07-01, before the clause existed — see
below) or `util.CABV116Date` (2013-07-29, correct as an *opening* date), and
**none carries an `IneffectiveDate`**.

**`n_sub_ca_eku_missing`'s opening date is also wrong**, by over a year:

```go
lint.RegisterCertificateLint(&lint.CertificateLint{
    LintMetadata: lint.LintMetadata{
        Name:          "n_sub_ca_eku_missing",
        Description:   "To be considered Technically Constrained, the Subordinate CA certificate MUST have extkeyUsage extension",
        Citation:      "BRs: 7.1.5",
        Source:        lint.CABFBaselineRequirements,
        EffectiveDate: util.CABEffectiveDate,
    },
```

`util.CABEffectiveDate` is 2012-07-01 — the Baseline Requirements' own start.
§7.1.5 (originally §9.7, "Technical Constraints in Subordinate CA Certificates
via Name Constraints and EKU") did not exist until ballot 105, BR 1.1.6,
effective **2013-07-29** — over a year later. Before that date, a Subordinate
CA Certificate's extkeyUsage was governed only by RFC 5280 (no BR-specific "to
be Technically Constrained" concept existed at all), so this lint's own
predicate — "MUST have extkeyUsage to be Technically Constrained" — cannot be
evaluated against a document that had not yet stated it. The sibling two lints
get the opening date right (`util.CABV116Date`).

**The bigger issue, shared by all three: the clause they cite stopped saying
what they say at BR 1.7.1 (SC-031, 2020-08-20), and none of the three
notices.** From 1.1.6 through 1.7.0, §7.1.2.2g reads (quoted in full in this
lane's `w_sub_ca_eku_critical/REASONING.md`):

> For Subordinate CA Certificates to be Technically constrained in line with
> section 7.1.5, then either the value id-kp-serverAuth [RFC5280] or
> id-kp-clientAuth [RFC5280] or both values MUST be present. Other values MAY
> be present. If present, this extension SHOULD be marked non-critical.

extkeyUsage is *optional*; the MUST is conditional on wanting the Technically
Constrained status. At BR 1.7.1 the clause is rewritten: for a
Cross-Certificate, extkeyUsage MAY still be absent; for **every other**
Subordinate CA Certificate, "This extension MUST be present and SHOULD NOT be
marked critical" — unconditional — and the serverAuth/clientAuth question is
reframed by whether the CA issues TLS certificates at all, not by whether it
claims the Technically Constrained status. Read in full from `br-1.7.1.txt`
directly (quoted at length in this lane's
`w_sub_ca_eku_critical/REASONING.md`).

**observed**: all three lints continue to apply the pre-1.7.1 reading — EKU
optional, absence and content merely informational to a voluntary constraint —
to certificates issued after 2020-08-20, when the clause they cite no longer
describes an optional extension for an ordinary Subordinate CA. **correct**:
from 1.7.1, an ordinary Subordinate CA Certificate's missing extkeyUsage is
`IsSubCA(c)`'s straightforward violation of an unconditional MUST, not
`n_sub_ca_eku_missing`'s informational Notice about a constraint the CA never
claimed to want.

**mechanism**: absence of `IneffectiveDate` on all three `LintMetadata` struct
literals (`n_sub_ca_eku_missing`'s wrong `EffectiveDate` besides), read
directly from source.

The post-1.7.1 MUST-based requirement is a different rule this lane does not
port; see this lane's `MANIFEST.md` for why that gap is left open rather than
folded into these three identifiers' gates.

**fix**: `IneffectiveDate: util.CABFBRs_1_7_1_Date` (confirmed present,
`v3/util/time.go` line 86, `= time.Date(2020, time.August, 20...)` — the same
constant `e_sub_ca_aia_does_not_contain_ocsp_url`'s own `IneffectiveDate`
uses) on all three; correct `n_sub_ca_eku_missing`'s `EffectiveDate` to
`util.CABV116Date`, matching its siblings; and a fourth, new lint for the
unconditional post-1.7.1 MUST, since none of the three existing ones states
it.

## What was not verified

- The installed `zlint` binary reports `-version dev-unknown` rather than the pinned `v3.7.1-20-g1007b1d5`; not confirmed to be a build of that exact commit.
