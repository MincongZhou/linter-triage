# ZT-018 — `e_qcstatem_pds_must_have_https_only` is dated ten years after its clause

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl, python3 |
| **Cases** | positive/ |
| **Verified against** | a real certificate from Mozilla bug 1481862 |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```go
Citation:      "ETSI EN 319 412 - 5 V2.4.1 (2023 - 09) / Section 4.3.4"
EffectiveDate: util.EtsiEn319_412_5_V2_4_1_Date   // 2023-09-01
```

QCS-4.3.4-03 — *"As a minimum, a URL to a PDS provided in this statement shall
use the 'https' (https://) scheme"* — is in EN 319 412-5 **v1.1.1, January
2013**, the document's first version, in the same words. Verified against the
complete series, now filed in `Specs/etsi/`: v1.1.1, v2.1.1, v2.2.1, v2.3.1,
v2.4.1, v2.5.1 and v2.6.1 all carry it. **v2.4.1 is where the requirement was
read, not where it began.**

The clause argues its own case in the sentence before, and the argument does
not depend on any version:

> The signature of the certificate does not cover the content of the PDS and
> hence does not protect the integrity of the PDS which can change over time.

Fix: date the lint to v1.1.1. **The two sibling `QcPDS` lints have the same
shape of problem** — `e_qcstatem_qcpds_valid` and `w_qcstatem_qcpds_lang_case`
are dated v2.2.1 while the requirements they enforce, an English PDS and the
ISO 639 language code, are also v1.1.1's.

It is worth saying plainly that the pattern is systemic rather than incidental
— zlint's effective dates are a catalogue of when requirements were
*implemented*, and reading them as when requirements *began* is what a
coverage comparison does by default.
