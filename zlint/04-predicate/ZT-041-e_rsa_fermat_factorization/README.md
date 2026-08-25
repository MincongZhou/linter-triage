# ZT-041 — `e_rsa_fermat_factorization` steps past the one modulus anybody can factor instantly

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool |
| **Cases** | positive/ and negative/ |
| **Verified against** | fabricated pair, recipe in `zlint/ZT-041-build.py` |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

The search starts one past where its own comment says it does:

```go
// Specifically, we set a = ceil(sqrt(n)), the first integer greater than
// the square root. Unfortunately, big.Int's built-in square root function
// takes the floor, so we have to add one to get the ceil.
a := new(big.Int)
a.Sqrt(n).Add(a, one)
```

`ceil(sqrt(n))` and `floor(sqrt(n)) + 1` are the same number for every `n`
except a perfect square, where they differ by one — and for a perfect square
the second is one step **past** the answer.

**A perfect square modulus is `n = p·p`, that is `p == q`.** It is the
degenerate endpoint of the exact defect this lint detects, a generator that
derives the second prime from the first and fails to advance, and it is the
easiest modulus in existence to factor: one square root, no search at all.
Fermat's method reaches it on its first round when `a` is computed correctly —
`a = p`, `b = 0`, `n = a² - b²`. The lint returns `pass`.

```
modulus is p*p (p == q)          {"e_rsa_fermat_factorization":{"result":"pass"}}
control: two primes 240 apart    {"e_rsa_fermat_factorization":{"result":"error", ...}}
```

**High rather than Medium because the subject decides whether the check
runs.** That is the question `linter-gap-reporting` says to lead with, and
here the answer is yes in the worst possible direction: the certificate that
most needs reporting is the one that escapes. It is not a check that is merely
absent — it is a check that returns `pass` on the input it was written for.

**Inherited rather than originated.** The function is transcribed from Let's
Encrypt's Boulder — `checkPrimeFactorsTooClose`, commit `89000bd`, credited in
the source — and the comment travelled with it. Boulder has the same defect
and is the better place to fix it; a report to zlint alone leaves the original
standing.

Fix: branch on whether `n` is a perfect square rather than adding one
unconditionally. Two lines, and the comment already describes the corrected
behaviour.

**Found by porting**, which is the pattern behind almost every entry here. The
port's own `n_rsa_fermat_factorization` computes the ceiling with the branch,
so its unit test for `p == q` passed while the reference returned `pass` on
the same shape — and the difference was then checked by running both rather
than by reading either.
