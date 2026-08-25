# XT-011 — the RSASSA-PSS salt-length check is inverted for SHA-384 and SHA-512

| | |
|---|---|
| **Tool** | `kroeckx/x509lint` at `103c92f` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ |
| **Verified against** | zlint's own fixtures |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```
SHA-256, salt 32  ->  no finding                  correct
SHA-384, salt 48  ->  E: Invalid PSS salt length  WRONG — 48 is what is required
SHA-512, salt 64  ->  E: Invalid PSS salt length  WRONG — 64 is what is required
```

Three zlint fixtures from one family, differing in the hash.

BR § 7.1.3.2.1 enumerates the permitted RSASSA-PSS parameter sets and fixes
the salt length to the hash output length: 32 bytes for SHA-256, **48** for
SHA-384, **64** for SHA-512. `CheckPSSSig` demands 32, **40** and **48**, with
`/* BR 7.1.3.2.1 */` on the branch:

```c
if ((hash_nid == NID_sha256 && salt_len != 32)
        || (hash_nid == NID_sha384 && salt_len != 40)
        || (hash_nid == NID_sha512 && salt_len != 48))
```

SHA-384 produces 48 bytes and SHA-512 produces 64. The SHA-256 limb is right,
which is why this survives casual testing.

**The check inverts on two of its three cases.** For SHA-384 it fires on every
salt length except 48 — that is, on every conforming certificate — and it
cannot fire on the 40-byte salt the clause actually forbids. Same for SHA-512
at 48. It is not merely wrong; it reports the population it exists to clear
and clears the population it exists to report.

It had also called the citation "correct", which it is: the clause is right
and the constants are not. Reading a tool's constants as though they were the
document is the specific way a comparison launders a defect into a
requirement.

Claims investigated and refuted are in [REFUTED.md](REFUTED.md), with the
evidence. They carry no number.
