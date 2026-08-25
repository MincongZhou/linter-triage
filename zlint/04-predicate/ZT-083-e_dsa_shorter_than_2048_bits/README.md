# ZT-083 — `e_dsa_shorter_than_2048_bits` tests `N >= 244`, and 244 is 224 transposed

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, python3 |
| **Cases** | positive/ and negative/ |
| **Verified against** | fabricated pair, recipe in the script |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```
$ zlint positive/ZT-083-dsa-2048-224.pem            # a real DSA key, L=2048 and N=224
e_dsa_improper_modulus_or_divisor_size   pass
e_dsa_shorter_than_2048_bits             error
```

One clause, two lints, opposite verdicts on the same certificate. BRs v1.7.0 §
6.1.5 names three DSA pairs — L=2048 with N=224, L=2048 with N=256, and L=3072
with N=256 — and both lints cite it. L=2048/N=224 is the **first** of the
three.

**The comparison.**
`v3/lints/cabf_br/lint_dsa_shorter_than_2048_bits.go:59-63`:

```go
L := dsaParams.P.BitLen()
N := dsaParams.Q.BitLen()
if L >= 2048 && N >= 244 {
    return &lint.LintResult{Status: lint.Pass}
}
return &lint.LintResult{Status: lint.Error}
```

FIPS 186-4 defines N as 160, 224 or 256. **244 is not a value `q` can take**,
and the digits are 224 transposed. Every conformant N except 256 takes the
error branch.

**Why it has survived.** The sibling lint states the same requirement
correctly, so the pair can only disagree on the one (L, N) pair no fixture
carries. zlint's six DSA fixtures have divisors of 160, 160, 256, 256, 256 and
256 — `dsaCert`, `dsaShorterThan2048Bits`, `dsaBadQLen`,
`dsaNotShorterThan2048Bits`, `dsaCorrectOrderInSubgroup` and `dsaUniqueRep` —
so nothing in the suite reaches the branch. The reproduction generates a real
2048/224 parameter set because none was available to borrow.

```go
if L >= 2048 && N >= 224 {
```

Or delete the lint. `e_dsa_improper_modulus_or_divisor_size` states § 6.1.5
completely and correctly; a requirement stated twice is how two
implementations of it come to disagree, and this is that.

**A second observation from the same reading, not numbered because it is a
scope choice rather than a defect.** `e_dsa_improper_modulus_or_divisor_size`
carries no `IneffectiveDate`, so it cites § 6.1.5's DSA table for certificates
issued after BR 1.7.1 (2020-08-20) deleted it — the section now reads "No
other algorithms or key sizes are permitted" and names no DSA pair at all. Its
`EffectiveDate` is `util.ZeroDate`, with the comment "taking the statement
'Before 31 Dec 2010' literally", so it also judges pre-2012 issuance against a
2012 document; the reproduction beside this file another entry here reports
that shape against cablint. `e_dsa_params_missing`, citing the adjacent §
6.1.6, uses `CABEffectiveDate` and `CABFBRs_1_7_1_Date` for both bounds. The
two lints disagree by twelve years at one end and by an open interval at the
other.
