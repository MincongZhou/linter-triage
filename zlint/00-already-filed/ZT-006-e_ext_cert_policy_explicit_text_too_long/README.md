# ZT-006 — `e_ext_cert_policy_explicit_text_too_long` counts bytes, not characters

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `00-already-filed` — Already on your issue tracker |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, python3 |
| **Cases** | positive/ |
| **Verified against** | real certificates |
| **Would otherwise sit in** | see the adjudication below |

## Upstream issues, adjudicated

- **#242** — Incorrect maximum length constraint checking for explicitText (bytes vs. characters) *(closed)*
  **duplicate.** The same 2018 report as ZT-002, closed 2019 without a fix.

## Analysis

RFC 6818 §3 states the `explicitText` ceiling in characters. The lint's
`Execute` builds

```go
runes = string(text.Bytes)      // or util.ParseBMPString(text.Bytes)
if len(runes) > 200 { Error }
```

The variable is named `runes` and holds a Go `string`, where `len` counts
UTF-8 bytes. An `explicitText` of exactly 200 characters containing any
non-ASCII character encodes to more than 200 octets and is faulted.

**Both arms are affected.** `util.ParseBMPString` also returns a `string`, so
the `BMPString` branch is a byte count too; it is not a correct branch to
copy. Fix: `len([]rune(...))` or `utf8.RuneCountInString` on both.
