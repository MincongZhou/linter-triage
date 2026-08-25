# ZT-019 — `e_etsi_natural_person_key_usage_mandatory` is dated four years after its clause

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | fabricated pair, same key, recipe in `zlint/ZT-019-build.py` |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```go
Citation:      "ETSI EN 319 412-2 V2.2.1 (2020-07) / Section 4.3.2"
EffectiveDate: util.EtsiEn319_412_2_V2_2_1_Date   // 2020-07-01
```

EN 319 412-2 **v2.1.1, February 2016** — the first edition of the document —
carries clause 4.3.2 in the same words:

> The key usage extension shall be present and shall contain one (and only one)
> of the key usage settings defined in table 1 (A, B, C, D, E or F).

v2.4.1 differs by one comma and by the requirement number `NAT-4.3.2-1`, which
the series gained when it took EN 319 411-1's numbering scheme. Verified
against the complete series, now filed in `Specs/etsi/`: v2.1.1, v2.2.1,
v2.3.1 and v2.4.1 all carry the sentence. **v2.2.1 is where the requirement
was read, not where it began.**

**The reason this one is worth reading closely.** The document's change
history *does* record a change request against this clause between the two
editions — "on key usage in ESI(18)63_039r1", implemented in v2.1.2 of
February 2020. A version search for the current wording therefore finds real
evidence of change, and it is evidence about the paragraph rather than about
the obligation.

Fix: date the lint to v2.1.1. **The two siblings on the same sentence have the
same problem and take the same fix** —
`e_etsi_natural_person_key_usage_correct_values` and
`w_etsi_natural_person_key_usage_preferred_values` both carry
`EtsiEn319_412_2_V2_2_1_Date` for clause 4.3.2, so it is one constant for
three lints.

**The seventh dating entry, and the fifth found on 2026-08-16.** `ZT-014`,
`ZT-015`, `ZT-016`, `ZT-017`, `ZT-018` and this one are the same mistake. What
this one adds is that the mistake can be *well-evidenced*: an amendment to a
clause is not the birth of the requirement in it, and only the archive
distinguishes them. It is the argument for holding every published version of
a document rather than the current one, made by the case that would have
defeated a careful reader with only the current one.
