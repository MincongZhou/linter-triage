# ZT-016 — `e_dnsname_empty_label` is dated to the document, not to its clause

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ |
| **Verified against** | real certificates |

## Upstream issues, adjudicated

- **#539** — Lints with wrong references (e.g. CABF when really RFC) *(open)*
  **related.** #539 tracks #538, which moved this lint from cabf_br to rfc -- a shelf claim. This entry is about the effective date it kept.

## Analysis

The lint declares `EffectiveDate: util.CABEffectiveDate` — 2012-07-01, the
date the Baseline Requirements themselves took effect. The clause it enforces
is younger. The dNSName syntax obligation enters the Requirements at **v1.6.7,
effective 2019-12-19**:

> Entries in the dNSName MUST be in the "preferred name syntax", as specified
> in RFC 5280, and thus MUST NOT contain underscore characters

RFC 1034 §3.5's preferred name syntax admits no empty label, so that is where
an empty label becomes a Baseline Requirements violation. Ballot SC-48
(v1.8.0, 2021-08-25) later restated it in terms of LDH Labels.

**Searching for "LDH" finds the restatement and not the obligation**, and
dates this twenty months late. The requirement is older than the words it is
now written in — take the earliest version whose text states the obligation,
whatever vocabulary it uses.

Every one of the 60 certificates predates 2019-12-19; the latest was issued
2019-05-13. Each is therefore faulted against a clause that did not bind it.

Not covered by [ZT-014](#zl-023), whose sweep was over lints whose declared
`Source` postdates their declared `EffectiveDate`. Here the two agree with
each other and the *clause content* postdates both, which that sweep cannot
see.

Fix: `EffectiveDate` of the BR 1.6.7 date rather than `util.CABEffectiveDate`.
