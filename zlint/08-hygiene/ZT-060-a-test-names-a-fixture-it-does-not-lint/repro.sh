#!/bin/bash
# ZT-060 — a test states an expectation next to a filename that does not
# produce it. lints/cabf_br/lint_dsa_correct_order_in_subgroup_test.go
# declares two tests over one filename: TestDSACorrectOrderSubgroup
# inputPath = "dsaCorrectOrderInSubgroup.pem" expected = lint.Pass
# (test.TestLint) TestDSANotCorrectOrderSubgroup inputPath =
# "dsaCorrectOrderInSubgroup.pem" expected = lint.Error (test.TestLintCert,
# after setting dsaKey.Y = P-1 on the parsed structure) The second lints an
# *x509.Certificate mutated in Go. The bytes it describes exist nowhere on
# disk. Anyone mining the suite for per-certificate ground truth records
# dsaCorrectOrderInSubgroup.pem -> Error, which is wrong.
# ./positive/ZT-060-repro.sh /path/to/zlint # binary only go test
# ./lints/cabf_br/ -run 'TestDSA' -v # from a zlint checkout
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"

echo "== the file both tests name, as it sits on disk"
"$Z" -includeNames=e_dsa_correct_order_in_subgroup \
     "$D/positive/ZT-060-dsa-correct-order-in-subgroup.pem" || echo FAILED

cat <<'NOTE'

Observed (zlint v3.7.1-20-g1007b1d5):

  {"e_dsa_correct_order_in_subgroup":{"result":"pass"}}

and from a checkout:

  $ go test ./lints/cabf_br/ -run 'TestDSACorrectOrderSubgroup|TestDSANotCorrectOrderSubgroup' -v
  === RUN   TestDSACorrectOrderSubgroup
  --- PASS: TestDSACorrectOrderSubgroup (0.00s)
  === RUN   TestDSANotCorrectOrderSubgroup
  --- PASS: TestDSANotCorrectOrderSubgroup (0.00s)

Both tests pass, and the file named by the one expecting Error returns pass.

test.TestLintCert is documented upstream as intentional — "useful when a unit
test reads a certificate from disk and then mutates it in some way before
trying to lint it" — so the helper is not the defect. The defect is that the
mutated case is labelled with the filename of the unmutated one, and there is
no artifact for the mutation. Three call sites do this:

lints/cabf_br/lint_dsa_correct_order_in_subgroup_test.go:44
lints/cabf_br/lint_dsa_unique_correct_representation_test.go:48
lints/community/lint_rsa_fermat_factorization_test.go:117

test.TestLintWithConfig (16 call sites) is a milder version: the same filename
carries two contradictory expectations distinguished only by a Go value.

A correct suite would serialise the mutated certificate to testdata/ and lint
it by filename, so that every stated expectation names bytes that exist. NOTE
