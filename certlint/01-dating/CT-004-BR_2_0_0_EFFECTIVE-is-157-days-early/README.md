# CT-004 — `BR_2_0_0_EFFECTIVE` is 157 days early

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl, a checkout of the tool (the script reads its source) |
| **Cases** | positive/ |
| **Verified against** | zlint fixture |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```
cablint.rb:27  BR_2_0_0_EFFECTIVE = Time.utc(2023, 4, 11)
                   # Effective date of BR v2.0.0, SC062.
```

The CA/Browser Forum's ballot table gives SC-62 as **adopted 2023-04-22,
effective 2023-09-15**. `2023-04-11` is neither — it is eleven days before
adoption.

**Its neighbours are what make this a slip rather than a misreading**:
`BR_1_7_1_EFFECTIVE = 2020-08-20` and `BR_2_0_1_EFFECTIVE = 2024-03-15` both
match the table exactly. Only 2.0.0 does not.

Two checks read it, and they move in opposite directions:

- `cablint.rb:335` — `unless ca_has_caissuers`, gated `not_before < BR_2_0_0_EFFECTIVE`. A warning that should still be given inside the window is **withheld**. The reproduction shows this: the same certificate through the same binary, one constant changed, and the warning appears. - `cablint.rb:330` — `unless ca_has_ocsp`, gated `>= BR_2_0_0_EFFECTIVE && < BR_2_0_1_EFFECTIVE`. A warning opens **157 days early**.

Fix: `Time.utc(2023, 9, 15)`. 91 of 116 published Baseline Requirements
versions took effect later than they were adopted, so a version's own date is
not its effective date.
