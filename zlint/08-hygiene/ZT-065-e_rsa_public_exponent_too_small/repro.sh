#!/bin/bash
# ZT-065 - e_rsa_public_exponent_too_small publishes another lint's
# description. BR 6.1.6 states two requirements in one sentence: "The CA
# SHALL confirm that the value of the public exponent is an odd number equal
# to 3 or more. Additionally, the public exponent SHOULD be in the range
# between 2^16+1 and 2^256-1." Three lints cite the clause. Two of them
# publish the identical Description, and it describes the SHALL:
# e_rsa_public_exponent_not_odd e is even -> error
# e_rsa_public_exponent_too_small e < 3 -> error
# w_rsa_public_exponent_not_in_range e outside the range -> warn
# e_rsa_public_exponent_too_small tests only "3 or more"; it does not test
# oddness, and it is not about the range its name suggests. Its Description
# claims both halves of a requirement it checks one half of. Not a coverage
# gap: w_rsa_public_exponent_not_in_range implements the SHOULD correctly.
# The artefact is that Description is published through -list-lints-json, so
# a reader building a policy table from that output is told
# e_rsa_public_exponent_too_small confirms an odd exponent. It does not.
# ./positive/ZT-065-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"

echo "== the three lints citing BRs: 6.1.6 about the public exponent"
"$Z" -list-lints-json \
  | grep -oE '\{"name":"[^"]*public_exponent[^"]*"[^}]*\}' \
  | sed -E 's/.*"name":"([^"]+)".*"description":"([^"]*)".*/  \1\n      \2/'

echo
echo "== the two identical descriptions"
"$Z" -list-lints-json \
  | grep -oE '\{"name":"[^"]*public_exponent[^"]*"[^}]*\}' \
  | sed -E 's/.*"description":"([^"]*)".*/\1/' | sort | uniq -c | sort -rn

echo
echo "== e = 3: odd, at least 3, below n. Only the SHOULD is breached."
"$Z" -includeNames \
  e_rsa_public_exponent_not_odd,e_rsa_public_exponent_too_small,w_rsa_public_exponent_not_in_range \
  "$D/positive/ZT-065-exponent-three.pem"

echo
echo "observed  e_rsa_public_exponent_too_small is described as confirming"
echo "          'an odd number equal to 3 or more'; it tests only e >= 3, and"
echo "          the string is e_rsa_public_exponent_not_odd's verbatim."
echo "correct   a description naming its own predicate, e.g."
echo "          'RSA: Value of public exponent is 3 or more.'"
