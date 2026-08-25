# ZT-091 — `w_ct_sct_policy_count_unsatisfied` is named `w_` and can only return a notice

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `08-hygiene` — Descriptions, citations, severities and tests |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | reproduced on a real certificate |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

zlint's contributor guide states the rule this breaks: *"Lints only return one
non-success or non-fatal status, which must also match their name prefix."*
`Execute` has two non-pass returns and both are `lint.Notice`; there is no
branch that can return `lint.Warn`. The lint's own test file asserts
`lint.Notice` at all six of its cases, so this is settled rather than
hypothetical, and the godoc says so in words — *"a Notice level
lint.LintResult is returned"*.

`LintStatus.String` renders `Notice` as `"info"`, so the JSON shows it
plainly:

```
$ zlint -includeNames w_ct_sct_policy_count_unsatisfied \
    
{"w_ct_sct_policy_count_unsatisfied":{"result":"info", "details":"..."}}
```

**observed** a `w_`-prefixed lint returning `info`. **correct** either the
name is `n_ct_sct_policy_count_unsatisfied`, or the status is `lint.Warn`.

`TestLintNames` in `v3/zlint_test.go` checks only that a name begins with one
of `n_`/`w_`/`e_`; nothing checks the name against the status, which is why
this survives the test suite.

**Low.** No verdict is falsified — the finding is right, and correctly hedged
as a notice given what a certificate can show. What is wrong is where the
finding is filed: a consumer selecting `w_` lints is handed a notice, and one
filtering by severity gets a lint it did not ask for.

**Same class as [`ZT-064`](zlint.md#zl-051)**, which is the `e_`-named
`w_qcstatem_qcpds_lang_case` returning both. This one is simpler: a single
status, and it is the wrong one for the name.

**Which of the two names is right is a judgement, not a mechanical fix.** The
lint's godoc argues for `Notice` because the policy's other branch delivers
SCTs over the connection and cannot be seen from a certificate — which is a
fair reading. Either is defensible; a name that contradicts the choice is not.

## Not recorded as a defect: the missing scope test

`CheckApplies` is `util.IsSubscriberCert(c) && !util.IsExtInCert(c,
util.CtPoisonOID)` and has no test for a TLS server certificate, while the
cited policy opens "Publicly trusted Transport Layer Security (TLS) server
authentication certificates must meet Apple's Certificate Transparency
policy". A code signing certificate is a subscriber certificate and is
admitted.

Recorded as an observation rather than an entry, because a claim with zero
demonstrated effect is a design disagreement and not a defect report. It is
worth stating next to ZT-078 because fixing that one would create it.

## What was not verified

- **No rebuild-and-diff.** The binary is `~/.local/bin/zlint`, `-version` `dev-unknown`, registering 431 lints. The vendored source at `pkimetal-linters/zlint` is `v3.7.1-20-g1007b1d5`. The lint count is consistent with that pin and nothing stronger was checked. - **No earlier revision of Apple's CT policy was consulted**, because none is held and none is published. The claim in ZT-078 is that the code does not implement the document it *currently* cites. It is not a claim about when the table changed. - **No SCT signature or log identity was checked**, by either tool. Both count identifiers. - The four validity sites in this lane were compared against zlint on samples (12 to 15 certificates in each direction, drawn at random from the firing set and from the silent applicable population) and **no disagreement was found**. That is a sample, not a census.
