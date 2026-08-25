# PT-002 — `cabf.internal_domain_name` reports two shapes that are not internal names

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | none of its own |
| **Verified against** | one real corpus certificate plus a direct call to the library pkilint delegates to |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

BR defines an Internal Name as one that "cannot be verified as globally unique
… does not end with a TLD registered in IANA's Root Zone Database"
(`Policies/Cert-BR-Baseline.md`). pkilint decides it with one line —
`PublicSuffixList(accept_unknown=False).publicsuffix(value) is None`
(`pkilint/cabf/cabf_name.py:256`) — and that line is wrong twice.

**The leading-dot nameConstraints form.**

```
publicsuffix('.dell.com' ) = None
publicsuffix('dell.com'  ) = 'com'
publicsuffix('.vipps.no' ) = None
publicsuffix('vipps.no'  ) = 'no'
```

**A gTLD removed after the certificate was issued.** a certificate from
Mozilla CA incident [bug
1795483](https://bugzilla.mozilla.org/show_bug.cgi?id=1795483),
`CN=bowel.cancerresearch`, issued **2022-07-22**.

**Whether a TLD was registered is a question with a date in it**, and a
snapshot of the present cannot answer it. The file contains no effective-date
logic at all.

**A third observation, not scored here.** `VALIDATION_INTERNAL_DOMAIN_NAME` is
raised by a container matched on `pdu_class=rfc5280.GeneralName`
(`pkilint/common/alternative_name.py:215`), so it reaches AIA and CRL-DP
`accessLocation`s, CPS URIs and nameConstraints subtrees — not only the CN and
SAN the BR definition is scoped to. 103 of the 553 fires are certificates
whose CPS URI is scheme-less, where `urlparse` yields an empty host and
`publicsuffix("")` is `None`. That is a scope question rather than a defect in
the predicate, and it is why the first shape above reaches nameConstraints at
all.

**Fix.** Strip one leading dot before the lookup when the value came from a
nameConstraints subtree; and carry delegation and removal dates, evaluated
against `notBefore`. zlint's `util/gtld_map.go` already publishes exactly that
data.
