#!/bin/bash
# ZT-041 — e_rsa_fermat_factorization steps past the one modulus anybody can
# factor instantly. The search starts at floor(sqrt(n)) + 1: a :=
# new(big.Int) a.Sqrt(n).Add(a, one) with the comment "we set a =
# ceil(sqrt(n)), the first integer greater than the square root". Those are
# two different numbers. For a perfect square they differ by exactly one,
# and floor(sqrt(n)) + 1 is one step PAST the answer. A perfect square
# modulus is n = p*p, that is p == q. It is the degenerate endpoint of the
# very defect this lint detects -- a generator that derives the second prime
# from the first and fails to advance -- and it is the easiest modulus in
# existence to factor: one square root, no search. The lint whose job is
# exactly this returns pass on it. Fermat's method reaches it on its first
# round when a is computed correctly: a = p, b = 0, n = a^2 - b^2. The
# branch is two lines: root := new(big.Int).Sqrt(n) if
# new(big.Int).Mul(root, root).Cmp(n) == 0 { a.Set(root) } else {
# a.Add(root, one) } INHERITED, NOT ORIGINATED. The function is transcribed
# from Let's Encrypt's Boulder (checkPrimeFactorsTooClose, commit 89000bd),
# and the comment is Boulder's too. Boulder has the same defect and is the
# better place to fix it. Certificates: fabricated, recipe in
# ZT-041-build.py.
set -u
Z=${ZLINT:-$HOME/.local/bin/zlint}
D=$(dirname "$0")
L=e_rsa_fermat_factorization
echo "zlint: $($Z -version 2>&1 | head -1)"
echo

printf '%-46s %s\n' "modulus is p*p (p == q)" \
  "$($Z -includeNames=$L "$D/positive/ZT-041-modulus-is-a-square.pem" 2>/dev/null | cut -c1-72)"
printf '%-46s %s\n' "control: two primes 240 apart" \
  "$($Z -includeNames=$L "$D/negative/ZT-041-control-close-primes.pem" 2>/dev/null | cut -c1-72)"

echo
echo "observed: pass on the square, error on the control"
echo "correct : error on both — p == q is the worst case of the property this"
echo "          lint exists to detect, and it factors in one square root"
echo "fix     : start the search at ceil(sqrt(n)) as the comment already says,"
echo "          which needs a branch on whether n is a perfect square. Report"
echo "          upstream to Boulder as well as to zlint."
