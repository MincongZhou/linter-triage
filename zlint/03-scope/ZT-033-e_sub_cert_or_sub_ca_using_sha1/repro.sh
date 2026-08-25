#!/bin/bash
# ZT-033 - e_sub_cert_or_sub_ca_using_sha1 applies to Root CA certificates,
# which the clause it cites exempts by name. func (l *sigAlgTestsSHA1)
# CheckApplies(c *x509.Certificate) bool { return true } The lint's own Name
# says "sub_cert_or_sub_ca", its Description says "Subscriber certificates
# or Subordinate CA certificates", and BR 1.2.1 section 9.4.2 -- the ballot
# 118 text this dates itself to via util.NO_SHA1 -- closes the exemption
# explicitly: Effective 1 January 2016, CAs MUST NOT issue any new
# Subscriber certificates or Subordinate CA certificates using the SHA-1
# hash algorithm. ... This Section 9.4.2 does not apply to Root CA or CA
# cross certificates. CAs MAY continue to use their existing SHA-1 Root
# Certificates. A root's self-signature is verified by nobody -- trust in a
# root comes from the store -- which is why the exemption exists and why the
# sunset for remaining SHA-1 uses had to be balloted separately in 2026.
# ./positive/ZT-033-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
C="$D/positive/ZT-033-selfsigned-sha1-root.pem"
N=e_sub_cert_or_sub_ca_using_sha1

echo "== the certificate: self-signed, CA:TRUE, SHA-1, issued after the cliff"
openssl x509 -in "$C" -noout -subject -issuer -startdate 2>/dev/null
openssl x509 -in "$C" -noout -text 2>/dev/null \
  | sed -n '/Signature Algorithm/{p;q}'
openssl x509 -in "$C" -noout -text 2>/dev/null | sed -n '/Basic Constraints/,+1p'

echo
echo "== what the lint declares about its own scope"
"$Z" -list-lints-json | grep -oE "\{\"name\":\"$N\"[^}]*\}" \
  | sed -E 's/.*"description":"([^"]*)".*/  description: \1/'

echo
echo "== what it does"
"$Z" -includeNames "$N" "$C"

echo
echo "observed  error on a Root CA certificate."
echo "correct   NA. BR 9.4.2 (ballot 118): \"This Section 9.4.2 does not apply"
echo "          to Root CA or CA cross certificates.\" CheckApplies should be"
echo "          util.IsSubCert(c) || util.IsSubCA(c), not \`return true\`."
