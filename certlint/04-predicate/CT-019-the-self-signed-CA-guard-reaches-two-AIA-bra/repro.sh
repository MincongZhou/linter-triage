#!/bin/bash
# CT-019 — cablint applies BR 7.1.2.2.c's OCSP-URL MUST to a self-signed
# root, although it computes and prints that the certificate is self-signed,
# and guards the two adjacent AIA/CDP branches on exactly that value.
# ./positive/CT-019-repro.sh /path/to/certlint-checkout
set -u
CL="${1:-.}"
D="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

run() { (cd "$CL" && ruby -Ilib -Iext bin/cablint "$1" 2>/dev/null) | sed 's/\t.*//'; }

echo "== SUBJECT: a self-signed root whose AIA carries caIssuers over http and no OCSP"
openssl x509 -in "$D/positive/CT-019-selfsigned-root-aia-no-ocsp.pem" -noout -subject -startdate 2>/dev/null | sed 's/^/   /'
openssl x509 -in "$D/positive/CT-019-selfsigned-root-aia-no-ocsp.pem" -noout -ext authorityInfoAccess 2>/dev/null | sed 's/^/   /'
openssl x509 -in "$D/positive/CT-019-selfsigned-root-aia-no-ocsp.pem" -outform der -out "$T/subject.der" 2>/dev/null
echo
run "$T/subject.der" | sed 's/^/   /'

echo
echo "== CONTROL: a self-signed root with NO authorityInformationAccess at all"
openssl x509 -in "$D/negative/CT-019-control-selfsigned-root-no-aia.pem" -noout -subject -startdate 2>/dev/null | sed 's/^/   /'
openssl x509 -in "$D/negative/CT-019-control-selfsigned-root-no-aia.pem" -outform der -out "$T/control.der" 2>/dev/null
echo
run "$T/control.der" | sed 's/^/   /'
echo "   (no AIA or OCSP finding: cablint.rb:296 guards that branch on is_self_signed_ca)"

cat <<'NOTE'

Observed: E: CA certificates must include an HTTP URL of the OCSP responder,
against a self-signed root -- on the same run that prints
          "I: Self-signed CA certificate identified".
Correct: silence. BR 7.1.2.1, the Root CA Certificate profile, states four
items -- basicConstraints, keyUsage, certificatePolicies, extendedKeyUsage --
and no authorityInformationAccess clause at all. The OCSP-URL MUST is
7.1.2.2.c, the SUBORDINATE CA profile.

THE MECHANISM

cablint computes the property at the top of the CA block and branches on it
immediately:

    cablint.rb:156   is_self_signed_ca = (is_ca && c.verify(c.public_key))
    cablint.rb:223   if is_ca
    cablint.rb:224     if is_self_signed_ca -> "I: Self-signed CA certificate identified"

and then guards two of the three AIA/CDP branches with it:

    cablint.rb:270   ca_crldp.nil?      -> if !is_self_signed_ca    GUARDED
    cablint.rb:296   ca_aia.nil?        -> if !is_self_signed_ca    GUARDED
    cablint.rb:327   unless ca_has_ocsp                            NOT GUARDED

Three branches about the same two extensions, two carrying the guard and one
not. That is what makes this a slip rather than a reading: nothing
distinguishes the third case, and the value it needs is already in scope.

WHAT DECIDES IT: the certificate is judged on whether the extension is present

A self-signed root with no AIA is silent. A self-signed root that carries an
AIA naming only caIssuers -- more information, not less -- is an error. Under
7.1.2.1 the extension is equally outside the profile either way.

Measured over the corpus (21,802 certificates): 666 self-signed roots issued on or
after 2012-07-01 carry no AIA and draw no finding here; 2 carry an AIA without
an OCSP entry and are reported. The third certificate in that set predates the
Baseline Requirements and belongs to CT-003.

FIX

    cablint.rb:327   unless ca_has_ocsp || is_self_signed_ca

matching the two branches above it. The caIssuers branch at 334 needs the same
treatment for the same reason. NOTE
