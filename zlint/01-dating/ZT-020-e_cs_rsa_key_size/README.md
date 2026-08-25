# ZT-020 — `e_cs_rsa_key_size` is dated 22 months before the RSA-3072 deadline

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | a real Sectigo code signing certificate from a certificate, with zlint's own fixture as the control |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```go
Citation:      CABF CS BRs 6.1.5.2
EffectiveDate: util.CABF_CS_BRs_1_2_Date   // 2019-08-13
```

The current § 6.1.5.2 states the requirement flatly — *"If the Key is RSA,
then the modulus MUST be at least 3072 bits in length"* — and a reader taking
that sentence to the document's first edition gets the date wrong by nearly
two years.

**CS BR v1.2 states it as a table with two dated columns**, Appendix A(1):

| | issued **prior to** 1 January 2021 | issued **on or after** 1 January 2021 |
|---|---|---|
| Minimum RSA modulus size (bits) | 2048 | 3072 |

and ballot **CSC-4**, v2.1, 7 November 2020 — titled *"Move deadline for
transition to RSA-3072 and SHA-2 timestamp tokens"* — moves the boundary to
**1 June 2021**. v2.4's Relevant Dates table gives `2021-06-01` against
Appendix A(1), and the undated sentence the lint quotes arrives in v2.4, after
the transition had closed.

So RSA-2048 was conformant in a code signing certificate for the first 22
months of the window this lint judges.

The reproduction is a real Sectigo/USERTrust code signing certificate issued
**19 March 2021** with an RSA-2048 key and `2.23.140.1.4.1` — eleven weeks
inside the deadline, and reported as an error. It sits in the archive, the
group where a finding *is* a false positive. The control is zlint's own
fixture for the lint, issued 2024, where the same key size is a real defect
and the same verdict is correct.

**Medium.** It reports conformant issuance as misissuance and zlint's results
are ground truth other tools consume. Not High: nothing is suppressed.

Fix: `CABF_CS_CSC_4_Date = 2021-06-01` as this lint's `EffectiveDate`.
`e_cs_ecdsa_prohibited_curve` cites the same section and needs no change —
both columns of the same table name P-256, P-384 and P-521.

**Found the way `another entry here` was not.** That entry guessed a family
from a shared constant and was refuted; this one came from reading the clause
in the edition the constant names, which is the same work done in the right
order. The shared constant is not the evidence — the column heading is.
