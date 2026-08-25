#!/bin/bash
# ZT-094 — BR 6.1.5's Subordinate CA table requires a 2048-bit modulus when
# the validity period begins after 31 Dec 2010 OR ends after 31 Dec 2013.
# zlint's four key-size lints cover only the second half of that
# disjunction, so a subordinate CA beginning in 2011-2013 and expiring
# before 2014 is judged by none of them. Certificates: fabricated, differing
# only in notBefore. Recipe below. ./positive/ZT-094-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
LINTS="e_old_root_ca_rsa_mod_less_than_2048_bits e_old_sub_ca_rsa_mod_less_than_1024_bits e_old_sub_cert_rsa_mod_less_than_1024_bits e_rsa_mod_less_than_2048_bits"

show() {
  "$Z" "$1" 2>/dev/null | python3 -c '
import json, sys
d = json.load(sys.stdin)
for k in sys.argv[1:]:
    print("      %4s  %s" % (d[k]["result"], k))
' $LINTS
}

for pair in "CONTROL:negative/ZT-094-control-subca-1024-begins-2010.pem:begins on or before 31 Dec 2010 -- BR permits 1024" \
            "SUBJECT:positive/ZT-094-subca-1024-begins-2011.pem:begins after 31 Dec 2010 -- BR requires 2048"; do
  IFS=: read -r label file note <<< "$pair"
  echo "== $label  ($note)"
  openssl x509 -in "$D/$file" -noout -subject -dates 2>/dev/null | sed 's/^/      /'
  openssl x509 -in "$D/$file" -noout -text 2>/dev/null | grep -E "Public-Key|CA:TRUE" | sed 's/^/      /'
  show "$D/$file"
  echo
done

cat <<'NOTE'
Observed: on the SUBJECT, all four key-size lints return NA. Nothing in zlint
judges the modulus of a subordinate CA whose validity period begins after 31
Dec 2010 and ends on or before 31 Dec 2013. Correct:
e_rsa_mod_less_than_2048_bits, or a lint of its own, reporting an error -- BR
6.1.5 requires 2048 bits of that certificate.

On the CONTROL, e_old_sub_ca_rsa_mod_less_than_1024_bits applies and passes,
which is right: 1024 was permitted there and the key is 1024 bits. The two
certificates differ in one field.

THE CLAUSE

BR 6.1.5 is three tables, one per certificate type, and each draws its line
somewhere different:

  Root CA          beginning on or before 31 Dec 2010          | after
  Subordinate CA   beginning on or before 31 Dec 2010 AND      | beginning after
                   ending on or before 31 Dec 2013             | 31 Dec 2010 OR
                                                               | ending after 31 Dec 2013
  Subscriber       ending on or before 31 Dec 2013             | ending after

zlint's four lints map onto them as:

  e_old_root_ca_rsa_mod_less_than_2048_bits   IsRootCA && issueDate < 2010-12-31
  e_old_sub_ca_rsa_mod_less_than_1024_bits    IsSubCA && issueDate < 2010-12-31
                                                       && endDate < 2014-01-01
  e_old_sub_cert_rsa_mod_less_than_1024_bits  !IsCACert && endDate < 2014-01-01
  e_rsa_mod_less_than_2048_bits               OnOrAfter(NotAfter, 2014-01-01)

The three "old" lints each mirror one left-hand column exactly. The fourth is
meant to be every right-hand column, and it tests only `notAfter`. For a
Subscriber that is the whole condition and the cover is complete. For a
Subordinate CA the condition is a DISJUNCTION and only one branch is
implemented; the same is true of a Root CA, whose right-hand column is keyed on
the beginning of the validity period and not its end.

zlint's own Description for the fourth lint says "For certificates valid after
31 Dec 2013" -- which is the Subscriber column, stated accurately. The lint
does what it says. The gap is that no other lint says the rest, so the
requirement is unreported by the tool as a whole.

REACH

Zero over the corpus (21,802 certificates): no certificate there is a subordinate
CA with a modulus of 1024 to 2047 bits, beginning after 2010-12-31 and ending
on or before 2013-12-31. The window closed thirteen years ago and issuance in
it is long expired, so this is a completeness finding about the clause rather
than a live source of missed certificates. It is recorded because a rule that
covers a clause and a rule that covers part of one look identical from
outside.

FIX

Widen the fourth lint's CheckApplies to the disjunction the tables state, per
certificate type:

    IsSubCA(c)   -> OnOrAfter(c.NotBefore, NoRSA1024RootDate)
                    || OnOrAfter(c.NotAfter, NoRSA1024Date)
    IsRootCA(c)  -> OnOrAfter(c.NotBefore, NoRSA1024RootDate)
    otherwise    -> OnOrAfter(c.NotAfter, NoRSA1024Date)     (unchanged)

and update the Description, which currently states only the third branch.

HOW THE CERTIFICATES WERE MADE

A throwaway 2048-bit root signs two 1024-bit subordinate CAs -- CA:TRUE,
pathlen 0, keyCertSign + cRLSign, serverAuth EKU, notAfter 2013-06-01 --
identical but for notBefore, 2010-06-01 against 2011-06-01. They are signed by
a root that is not in any trust store and are useless for anything but this
test. The issuing root is beside them as positive/ZT-094-issuing-root.pem so
the chain can be inspected. NOTE
