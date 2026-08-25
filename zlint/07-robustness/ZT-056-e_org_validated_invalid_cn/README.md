# ZT-056 — `e_org_validated_invalid_cn` panics on the subject shape its own clause permits

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `07-robustness` — Panics, run-ending failures, and non-determinism |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | zlint's own fixtures, unmodified |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```go
Description: "In OV S/MIME certs, the Subject CN must either contain an email
              address or match organizatioName"
Citation:    CABF SMIME BRs §7.1.4.2.2
```

`Execute` indexes the organizationName slice without testing it:

```go
if isEmail(c.Subject.CommonName) ||
        c.Subject.CommonName == c.Subject.Organization[0] {
        return &lint.LintResult{Status: lint.Pass}
}
```

`isEmail("")` is false, so a certificate with no `commonName` falls through to
the index; if it also carries no `organizationName`, the index is out of
range. `lint.CertificateLint.Execute` recovers per-lint, so the run survives
and this lint records

```
Fatal: 'e_org_validated_invalid_cn' panicked.
       Error: runtime error: index out of range [0] with length 0
```

Both halves are wrong on their own terms as well. §7.1.4.2.2(a) opens *"If
present, this attribute SHALL contain one of the following values"* and the
§7.1.4.2.4 table states `commonName` as MAY, so an absent `commonName` is
conformant and the answer is `NA`. The certificate in the reproduction —
`C=GB, organizationIdentifier=NTRGB-12345678` — breaches nothing this lint is
about.

**The fix is already written upstream and unmerged.** `origin/pr1069_followup`
carries both halves against master `1007b1d5`, which is the commit that added
the lint (PR #1069):

```go
CheckApplies: ... && c.Subject.CommonName != ""
Execute:      ... || (len(c.Subject.Organization) > 0 &&
                      c.Subject.CommonName == c.Subject.Organization[0])
```

So the action upstream is to land that branch, not to write a patch. The entry
stays because the pinned version panics and because a fix on an unmerged
branch is not a fix in any released artifact.
