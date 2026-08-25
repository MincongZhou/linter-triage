#!/bin/bash
# CT-004 — BR_2_0_0_EFFECTIVE is 2023-04-11 where ballot SC-62's effective
# date is 2023-09-15, so two checks change behaviour 157 days early.
# ./positive/CT-004-repro.sh /path/to/certlint-checkout
set -u
CL="${1:-/path/to/certlint}"
D="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
openssl x509 -in "$D/positive/CT-004-in-window.pem" -outform der -out "$T/c.der" 2>/dev/null

echo "== a subordinate CA issued inside the window, AIA carrying OCSP and no caIssuers"
openssl x509 -in "$D/positive/CT-004-in-window.pem" -noout -startdate 2>/dev/null | sed 's/^/   /'
openssl x509 -in "$D/positive/CT-004-in-window.pem" -noout -ext authorityInfoAccess 2>/dev/null \
  | grep -v '^Auth' | sed 's/^/   /'
echo
echo "== as shipped, BR_2_0_0_EFFECTIVE = 2023-04-11"
grep -n 'BR_2_0_0_EFFECTIVE = ' "$CL/lib/certlint/cablint.rb" | sed 's/^/   /'
(cd "$CL" && ruby -Ilib -Iext bin/cablint "$T/c.der" 2>/dev/null | sed 's/\t.*//' \
  | grep "issuing CA") | sed 's/^/   /'
echo "   (nothing above: no warning about the issuing CA's certificate)"

echo
echo "== the same tree with the constant set to the ballot table's 2023-09-15"
cp -r "$CL" "$T/fixed"
sed -i 's/BR_2_0_0_EFFECTIVE = Time.utc(2023, 4, 11)/BR_2_0_0_EFFECTIVE = Time.utc(2023, 9, 15)/' \
  "$T/fixed/lib/certlint/cablint.rb"
(cd "$T/fixed" && ruby -Ilib -Iext bin/cablint "$T/c.der" 2>/dev/null | sed 's/\t.*//' \
  | grep "issuing CA") | sed 's/^/   /'

cat <<'NOTE'

Observed: no warning, because the certificate's notBefore is treated as on or
after BR 2.0.0. Correct: W: CA certificates should include an HTTP URL of the
issuing CA's certificate -- the certificate was issued while BR 1.x still
bound.

THE DATE

    cablint.rb:27  BR_2_0_0_EFFECTIVE = Time.utc(2023, 4, 11)
                       # Effective date of BR v2.0.0, SC062.

The CA/Browser Forum's own ballot table gives SC-62 as **adopted 2023-04-22,
effective 2023-09-15**. 2023-04-11 is neither -- it is eleven days before
adoption. The window is 157 days wide.

This is a slip rather than a misreading, and its neighbours are what show that:

    BR_1_7_1_EFFECTIVE = 2020-08-20   correct (SC030 and SC031)
    BR_2_0_1_EFFECTIVE = 2024-03-15   correct (SC063)

Both siblings match the ballot table exactly. Only 2.0.0 does not.

WHAT IT CHANGES, in both directions

  cablint.rb:335  unless ca_has_caissuers / if not_before < BR_2_0_0_EFFECTIVE
A warning that should still be given inside the window is WITHHELD. That is
what this reproduction shows.

  cablint.rb:330  unless ca_has_ocsp / elsif not_before >= BR_2_0_0_EFFECTIVE
                                        && not_before < BR_2_0_1_EFFECTIVE
        A warning opens 157 days EARLY.

Bounded: only certificates with notBefore in [2023-04-11, 2023-09-15) are
affected, and only these two checks read the constant.

FIX

    BR_2_0_0_EFFECTIVE = Time.utc(2023, 9, 15)

91 of 116 published Baseline Requirements versions took effect later than they
were adopted, so a version's own date is not its effective date and the ballot
table is the source for both. NOTE
