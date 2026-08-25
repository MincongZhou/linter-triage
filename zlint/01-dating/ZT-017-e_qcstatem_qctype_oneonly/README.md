# ZT-017 — `e_qcstatem_qctype_oneonly` takes its date from a constant naming a different document

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl, python3 |
| **Cases** | positive/ and negative/ |
| **Verified against** | three of zlint's own fixtures |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```go
Citation:      "ETSI EN 319 412 - 5 V2.5.0 (2025 - 03) / Section 4.2.3"
EffectiveDate: util.EtsiEn319_411_2_V2_5_0_Date   // = 2023-07-01
```

The citation names **EN 319 412-5**; the constant is named for **EN 319
411-2**, a different document in the same series, and carries 2023-07-01.
Neither is the clause's own date. § 4.2.3's "one and only one of the purposes
of electronic signature, electronic seal or web site authentication" is in EN
319 412-5 **v2.2.1, effective 2017-11-01** — which is the date zlint's own two
sibling `QcType` lints use: `e_qcstatem_qctype_web` and
`e_qcstatem_qctype_smime` both take `util.EtsiEn319_412_5_V2_2_1_Date`.
**Three lints, one clause, two dates**, and the odd one out is the only one
whose constant names another document.

Fix: `util.EtsiEn319_412_5_V2_2_1_Date`, as the siblings already use, and a
citation naming the version that states the clause rather than the newest one
that repeats it.
