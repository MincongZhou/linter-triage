# ZT-094 — BR § 6.1.5's Subordinate CA column is a disjunction, and one branch of it is unlinted

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `09-absent` — A requirement no check covers |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl, python3 |
| **Cases** | positive/ and negative/ |
| **Verified against** | fabricated pair, recipe in the script |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```
$ zlint positive/ZT-094-subca-1024-begins-2011.pem    # sub CA, RSA 1024, 2011-06-01 -> 2013-06-01
  NA  e_old_root_ca_rsa_mod_less_than_2048_bits
  NA  e_old_sub_ca_rsa_mod_less_than_1024_bits
  NA  e_old_sub_cert_rsa_mod_less_than_1024_bits
  NA  e_rsa_mod_less_than_2048_bits
```

Four key-size lints and not one of them judges the certificate. BR § 6.1.5
requires a 2048-bit modulus of it: the Subordinate CA table's right-hand
column is "validity period beginning after 31 Dec 2010 **or** ending after 31
Dec 2013", and this certificate satisfies the first branch.

**The three "old" lints each mirror one left-hand column exactly, and the
fourth is meant to be all three right-hand columns.**

```
e_old_root_ca_rsa_mod_less_than_2048_bits   IsRootCA && issueDate < 2010-12-31
e_old_sub_ca_rsa_mod_less_than_1024_bits    IsSubCA && issueDate < 2010-12-31
                                                    && endDate < 2014-01-01
e_old_sub_cert_rsa_mod_less_than_1024_bits  !IsCACert && endDate < 2014-01-01
e_rsa_mod_less_than_2048_bits               OnOrAfter(c.NotAfter, 2014-01-01)
```

The fourth tests `notAfter` alone. For a Subscriber that is the whole
condition and the cover is complete. For a Subordinate CA it is one branch of
a disjunction, and for a Root CA it is the wrong bound entirely — that table's
right-hand column is keyed on when the validity period *begins*.

**The lint is not lying about itself**, which is why this is a completeness
finding rather than a behaviour one: its Description reads "For certificates
valid after 31 Dec 2013, all certificates using RSA public key algorithm MUST
have 2048 bits of modulus", which is the Subscriber column stated accurately.
Every lint here does what it says. What no lint says is the rest of the
clause, and a reader consulting `Citation: BRs: 6.1.5` across the four gets no
signal that a window is uncovered.

The control settles that the window is the cause and not the shape of the
certificate: the same certificate with `notBefore` moved back to 2010-06-01
reaches `e_old_sub_ca_rsa_mod_less_than_1024_bits`, which applies and passes —
correctly, because 1024 was permitted there and the key is 1024 bits. One
field apart, and one is judged.

Fix: make the fourth lint's `CheckApplies` the disjunction the tables state,
branching on certificate type, and correct the Description to match.

```go
IsSubCA(c)  -> util.OnOrAfter(c.NotBefore, util.NoRSA1024RootDate) ||
               util.OnOrAfter(c.NotAfter,  util.NoRSA1024Date)
IsRootCA(c) -> util.OnOrAfter(c.NotBefore, util.NoRSA1024RootDate)
otherwise   -> util.OnOrAfter(c.NotAfter,  util.NoRSA1024Date)      // unchanged
```
