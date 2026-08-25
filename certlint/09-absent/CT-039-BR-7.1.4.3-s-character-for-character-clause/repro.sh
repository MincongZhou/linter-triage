#!/bin/bash
# CT-039 — BR 7.1.4.3 requires a commonName that holds an FQDN to be "a
# character-for-character copy of the dNSName entry value". cablint compares
# case-insensitively by design, so no message it can emit reports that
# clause. Certificates: both real, from the Bugzilla incident archive.
# ./positive/CT-039-repro.sh /path/to/certlint-checkout
set -u
CL="${1:-.}"
D="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

run() {
  openssl x509 -in "$1" -outform der -out "$T/c.der" 2>/dev/null
  (cd "$CL" && ruby -Ilib -Iext bin/cablint "$T/c.der" 2>/dev/null) | sed 's/\t.*//' \
    | grep -iE "commonName|SAN entries" || echo "   (nothing about the commonName)"
}

echo "== SUBJECT: the commonName differs from its dNSName only in case"
openssl x509 -in "$D/positive/CT-039-cn-case-differs-from-san.pem" -noout -subject -ext subjectAltName 2>/dev/null \
  | grep -v "^X509v3" | sed 's/^/      /'
run "$D/positive/CT-039-cn-case-differs-from-san.pem" | sed 's/^/   /'

echo
echo "== CONTROL: the commonName is not in the subjectAltName at all"
openssl x509 -in "$D/negative/CT-039-control-cn-absent-from-san.pem" -noout -subject -ext subjectAltName 2>/dev/null \
  | grep -v "^X509v3" | sed 's/^/      /'
run "$D/negative/CT-039-control-cn-absent-from-san.pem" | sed 's/^/   /'

cat <<'NOTE'

Observed: silence on the subject. `ZG-VSW-GERESP02.zg.ch` in the commonName
          against `zg-vsw-geresp02.zg.ch` in the subjectAltName is not a
character-for-character copy, and no cablint message says so. Correct: an
error. BR 7.1.4.3 is explicit --

            "If the value is a Fully-Qualified Domain Name or Wildcard Domain
Name, then the value MUST be encoded as a character-for-character copy of the
dNSName entry value from the subjectAltName
             extension."

The control shows the membership check working: a commonName of `ov` against a
dNSName of `www.test.cn` is reported. So this is the clause and not the code
path.

THE MECHANISM, AND WHY THIS IS NOT A BUG IN THE CHECK

cablint.rb:723 # To check that the CN matches a SAN entry, first check for #
case insensitive direct match cablint.rb:725 # RFC 5891 section 3.1.2 makes
this clear: # A pair of A-labels MUST be compared as case-insensitive
                    #  ASCII (as with all comparisons of ASCII DNS labels).
    cablint.rb:731  unless names.include? val.downcase

The check is deliberate, reasoned, and correct about DNS comparison. Its own
message says "must be from SAN entries", which is a claim about MEMBERSHIP, and
it answers that claim exactly. What is missing is a second check for the
ENCODING clause, which the Baseline Requirements added separately and which is
not a DNS-comparison question at all: two names that are the same host can
still fail it.

Both other implementations carry it as its own identifier —
because the older membership clause and the newer encoding clause are two
requirements, dated differently. zlint reports the subject certificate here as
`error` and reports the older membership lint as `NE`, its era having passed.

REACH

pair: **40 certificates** carry a commonName that is a case-differing copy of
a dNSName entry. cablint reports none of them. Twenty-five are from Bugzilla
1874196 alone.

FIX

A second comparison after the case-insensitive one, for certificates issued on
or after BR 1.8.0 (2021-08-25), reporting a commonName that matches a dNSName
case-insensitively and not exactly. The value is already in hand at line 731 --
`names` holds the downcased entries and `val` the original, so the exact form
has to be carried alongside. NOTE
