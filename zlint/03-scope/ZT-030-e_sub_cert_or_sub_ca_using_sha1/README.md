# ZT-030 — `e_sub_cert_or_sub_ca_using_sha1` fires on a root its own Description excludes

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `03-scope` — Applied outside the population the clause governs |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ |
| **Verified against** | zlint's own fixture |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```go
Description: "CAs MUST NOT issue any new Subscriber certificates or
              Subordinate CA certificates using SHA-1 after 1 January 2016"

func (l *sigAlgTestsSHA1) CheckApplies(c *x509.Certificate) bool {
    return true
}
```

**Not the ZT-001 or ZT-029 pattern.** Those rested on guarded halves of pairs
— a `sub_cert` lint beside a `sub_ca` one that guards correctly. There is no
second lint for this question, so the contrast is internal: the lint's stated
scope against its own guard.

Fix: `CheckApplies` should be `!util.IsRootCA(c)`.
