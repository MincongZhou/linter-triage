# ZT-078 — `w_ct_sct_policy_count_unsatisfied` implements a superseded revision of the table it cites

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | reproduced on real certificates from a CA compliance bug and on zlint's own fixtures |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

The lint's `Citation` is `https://support.apple.com/en-us/HT205280`, which
redirects to `https://support.apple.com/en-us/103214`, *Apple's Certificate
Transparency policy*, Published Date 2025-04-21. That page states the embedded
SCT requirement as:

| Certificate lifetime | # of SCTs from distinct logs |
|---|---|
| 180 days or less | 2 |
| 181 to 398 days | 3 |

`appleCTPolicyExpectedSCTs` implements a different table, reproduced verbatim
in the lint's own godoc:

```
| Less than 15 months  | 2 |
| 15 to 27 months      | 3 |
| 27 to 39 months      | 4 |
| More than 39 months  | 5 |
```

Those are the thresholds of an earlier revision of the same page. They are not
in the document the lint cites, and the two disagree over the whole population
between 181 and 398 days — which, since the 398-day maximum took effect in
2020, is most publicly-trusted TLS issuance.

```
$ zlint -includeNames w_ct_sct_policy_count_unsatisfied \
    
{"w_ct_sct_policy_count_unsatisfied":{"result":"pass"}}
```

**observed** `pass` — 365 days is under 15 months, so the implemented table
asks for two and the certificate has two. **correct** a finding — the cited
table puts 365 days in the "181 to 398 days" row, which asks for three.

**Control**, from zlint's own fixture set as vendored here — the same shape at
a different lifetime, and the same disagreement:
`evidence/zlint/ecc_key_dv_with_key_agreement.pem`, 198 days, two distinct
logs, `pass` from zlint and a finding under the cited table.

A second, independent symptom of the same cause is visible in the lint's own
`Details` string on a certificate with no embedded SCTs:

```
$ zlint -includeNames w_ct_sct_policy_count_unsatisfied \
    
{"w_ct_sct_policy_count_unsatisfied":{"result":"info",
 "details":"Certificate had 0 embedded SCTs. Browser policy may require 5 for this certificate."}}
```

Five is the ">39 months" row. The cited policy has no row past 398 days at
all, so "may require 5" is a number the current document cannot produce.

**Medium, not High.** The check still runs, the certificate cannot suppress
it, and it still reports the certificates that fail the *old* table. What it
does is fail to report a real requirement over a bounded population — every
certificate between 181 and 398 days carrying exactly two SCTs.

**Fix** — replace the table with the cited one and add an `IneffectiveDate`/
`EffectiveDate` pair, or a second lint, so that certificates issued before the
revision are judged by the revision in force at the time. That second half is
harder than it sounds and is the reason this is a report rather than a patch:
**Apple archives no superseded revision of the article**, so the date each
table came into force is not recoverable from the publisher. zlint's own
`util.AppleCTPolicyDate` (2018-10-15) is the policy's start, not the current
table's.
