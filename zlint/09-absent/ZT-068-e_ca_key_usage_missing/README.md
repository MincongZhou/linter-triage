# ZT-068 — no lint reports a subscriber certificate with no keyUsage

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `09-absent` — A requirement no check covers |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool |
| **Cases** | positive/ |
| **Verified against** | fixture `ecdsaP256AbsentKU.pem` |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

BR §7.1.2.7.6 gives `keyUsage` as SHOULD, critical. On a serverAuth subscriber
carrying AKI, SKI and EKU but no keyUsage, all 25 key-usage lints return `NA`.

The adjacent names are CA-scoped (`e_ca_key_usage_missing`,
`e_root_ca_key_usage_present`), conditional on presence
(`e_sub_cert_key_usage_*_bit_set`), gated on `util.HasKeyUsageOID`
(`e_cabf_ecc_allowed_key_usages`), or from another document
(`e_key_usage_presence` is the S/MIME BR, `e_cs_key_usage_required` the CS
BR). No `w_sub_cert_key_usage_missing` exists.

Absence established by enumerating all 431 registered lints and searching
several ways, not by one grep.
