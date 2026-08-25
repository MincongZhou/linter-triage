# ZT-061 — six lints carry a Go identifier where a citation belongs

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `08-hygiene` — Descriptions, citations, severities and tests |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | no certificate needed |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```
14  "citation":"awslabs certlint"
 6  "citation":"lint.AWSLabs certlint"
```

Twenty lints take their requirement from the same community source. Six cite
it with the Go package selector for the source constant rather than the
source: `w_{issuer,subject}_dn_{leading,trailing}_whitespace`,
`n_multiple_subject_rdn` and `e_validity_time_not_positive`.

`Citation` is human-readable metadata published through `-list-lints-json`,
which is how downstream tools build documentation and policy tables — so the
artefact reaches anyone consuming that output, not only someone reading the
source.

Fix: the string the other fourteen use.
