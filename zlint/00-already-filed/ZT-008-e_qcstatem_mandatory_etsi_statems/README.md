# ZT-008 — `e_qcstatem_mandatory_etsi_statems` reports a clause about EU qualified certificates against certificates that are not one

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `00-already-filed` — Already on your issue tracker |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | a real FNMT-RCM certificate against zlint's own fixture as the control |
| **Would otherwise sit in** | see the adjudication below |

## Upstream issues, adjudicated

- **#424** — Bug: ETSI ESI QCStatements can appear in non-qualified certificates *(open)*
  **duplicate.** The same claim, filed by a maintainer in 2020 after Mozilla bug 1625421, and still open. The thread's conclusion was to demote to warning or remove; neither happened.
- **#581** — Bug: ESI lints are not consistent with ETSI EN 319 412-5 requirements regarding non-qualified certificates *(open)*
  **duplicate.** The same claim, broader -- it also names w_qcstatem_qctype_web. Maintainers reply with a +1 to removing the ETSI lints entirely.

## Analysis

The lint cites `ETSI EN 319 412 - 5 V2.2.1 (2017 - 11) / Section 5`. That
section states one requirement:

> QCS-5-01: EU qualified certificates shall include QCStatements in accordance
> with table 2.

Table 2 marks `esi4-qcStatement-1` — `QcCompliance` — **M**. `CheckApplies`
never asks whether the certificate is an EU qualified certificate:

```go
func (l *qcStatemQcmandatoryEtsiStatems) CheckApplies(c *x509.Certificate) bool {
	if !util.IsExtInCert(c, util.QcStateOid) {
		return false
	}
	if util.IsAnyEtsiQcStatementPresent(util.GetExtFromCert(c, util.QcStateOid).Value) {
		return true
	}
	return false
}
```

The lint's `Description` states that predicate honestly — "Checks that a QC
Statement that contains at least one of the ETSI ESI statements, also features
the set of mandatory ETSI ESI QC statements" — so **the behaviour matches the
description and contradicts the citation**, which is the normative half.
Several ETSI ESI statements are defined for non-qualified use: EN 319 412-5
§4.2.3 says `QcType` on its own "indicates that it is used for the purposes
of... non-qualified certificates", and `QcPDS` and `QcRetentionPeriod` are
generic statements EN 319 411-1 applies to non-qualified certificates too.

The predicate is also circular. `QcCompliance` *is* how a certificate claims
EU qualified status, so demanding it because it is absent assumes the answer.
The other claim available is a policy identifier: **EN 319 411-2's arc
`0.4.0.194112.1.`** is the qualified series (QCP-n, QCP-l, QEVCP-w, QNCP-w),
and **EN 319 411-1's arc `0.4.0.2042.1.`** is the non-qualified one (NCP, LCP,
EVCP, DVCP, **OVCP**, PTC). One digit of one arc decides it, and
`CheckApplies` reads neither.

### Reach

| | certificates |
|---|---|
| assert an EN 319 411-2 **qualified** policy | 2 (both zlint's own fixtures) |
| assert **no** qualified policy | 94 |
| — of those, asserting OVCP `0.4.0.2042.1.7` | 90 |
| — asserting `1.2.250.1.86.2.3.1.60.1` and no ETSI arc | 4 |

### This was adjudicated in 2020, against the lint

Mozilla bug **1625421**, 2020-03-27: 21 FNMT-RCM precertificates reported for
this lint (`crt.sh?zlint=1193`). FNMT **suspended issuance** from `AC
Componentes Informáticos` on 2020-03-28 while it investigated — the cost of
this false positive is on the record. The CA's analysis named the three
statements it carries (`QcRetentionPeriod`, `QcPDS`, `QcType(qct-web)`) under
its OVCP profile. The reviewer's conclusion, 2020-03-30:

> I agree, that the use of these QCStatements does not imply a Qualified
> certificate, and thus does not imply a violation of ETSI EN 319 412-5 / ETSI
> EN 319 411-2

He filed **zlint issue 424** the same day. The bug was closed
**RESOLVED/INVALID**. The lint is unchanged in `v3.7.1-20-g1007b1d5`, six
years later, and still reports the same profile.

**Fix**: gate `CheckApplies` on an EN 319 411-2 policy identifier (prefix
`0.4.0.194112.1.`) rather than on `util.IsAnyEtsiQcStatementPresent`. Match
the arc rather than enumerating, since EN 319 411-2 has added policies since
(QNCP-w-gen in v2.4.1) and a list fails silently toward not reporting.

**This port had the same bug**, having taken zlint's predicate with its name.
