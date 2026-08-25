# PT-016 — the commonName-from-SAN check compares DNS names case-sensitively

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ |
| **Verified against** | a real 2017 HSBC certificate |

## Upstream issues, adjudicated

- **#13** — Unknown CN value source *(closed)*
  **related.** A user asking what cabf.smime.common_name_value_unknown_source means on their own certificate. Evidence the finding is reached in the wild and is not self-explanatory; not a defect report, and not this claim.

## Analysis

`pkilint/common/common_name.py:57`:

```python
if str(gn_value.pdu) == value_str:
```

A case-sensitive Python string comparison of the commonName against each SAN
`dNSName`. BR § 7.1.4.3 requires the commonName value to be one of the values
in the subjectAltName; it says nothing about byte casing, and could not,
because the two spellings denote the same host — RFC 1035 § 2.3.3 and RFC
4343, whose title is *"Domain Name System (DNS) Case Insensitivity
Clarification"*.

The reproduction's certificate carries
`CN=GBWDC300VG032.mra-emea-uat.hsbc.com` and a SAN whose first entry is
`gbwdc300vg032.mra-emea-uat.hsbc.com`. One name, reported as an unknown
source.

The `IP_ADDRESS` branch immediately below compares decoded octets and has no
equivalent problem. Only the DNS branch is affected.

**Fix.** Casefold both sides: `if str(gn_value.pdu).lower == value_str.lower:`

`CommonNameValidator` is shared, so the same comparison decides
`cabf.smime.common_name_value_unknown_source` and
`etsi.en_319_412_4.web-4.1.3-4.common_name_unknown_source`. Only the
serverauth code was measured.
