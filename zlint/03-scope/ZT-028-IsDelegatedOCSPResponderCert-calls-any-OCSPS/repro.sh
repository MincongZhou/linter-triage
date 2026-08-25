#!/bin/bash
# ZT-028 — e_ocsp_id_pkix_ocsp_nocheck_ext_not_included_server_auth treats
# any certificate whose EKU merely contains id-kp-OCSPSigning as a delegated
# OCSP responder, CA certificates included.
# lints/cabf_br/lint_ocsp_id_pkix_ocsp_nocheck_ext_not_included_server_auth.go:
# func (l *...) CheckApplies(c *x509.Certificate) bool { return
# util.IsDelegatedOCSPResponderCert(c) } util/ca.go: func
# IsDelegatedOCSPResponderCert(cert *x509.Certificate) bool { return
# HasEKU(cert, x509.ExtKeyUsageOcspSigning) } Inclusion of the purpose, on
# any certificate. A subordinate CA that lists id-kp-OCSPSigning beside
# serverAuth and clientAuth — which is how a CA declares that it signs OCSP
# responses with its own key — is then required, at error, to carry
# id-pkix-ocsp-nocheck. It is not a delegated responder. RFC 6960 4.2.2.2
# lists three ways a responder's certificate may be accepted, and the CA's
# own certificate is criterion 2, distinct from criterion 3's "includes a
# value of id-kp-OCSPSigning ... and is issued by the CA". 4.2.2.2.1, the
# clause that introduces id-pkix-ocsp-nocheck, is headed "Revocation
# Checking of an Authorized Responder" and is about the delegated case only.
# BR 7.1.2.8 opens "If the Issuing CA does not directly sign OCSP responses,
# it MAY make use of an OCSP Authorized Responder", and 7.1.2.8.6 places the
# MUST inside that profile. The CA certificate extension tables list
# id-pkix-ocsp-nocheck nowhere; it reaches them only as "Any other
# extension: NOT RECOMMENDED". So the lint requires, at error, an extension
# the governing document does not recommend for the certificate it is asking
# about — and one whose meaning is that the holder's revocation status need
# not be checked, which is not a thing to ask of a CA. The two inputs below
# differ in basicConstraints. Both carry id-kp-OCSPSigning and neither
# carries id-pkix-ocsp-nocheck. ./positive/ZT-028-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
N=e_ocsp_id_pkix_ocsp_nocheck_ext_not_included_server_auth

for f in positive/ZT-028-subordinate-ca-ocspsigning.pem \
         negative/ZT-028-control-delegated-responder.pem ; do
  echo "== $f"
  openssl x509 -in "$D/$f" -noout -ext basicConstraints,extendedKeyUsage 2>/dev/null \
    | sed 's/^/   /'
  "$Z" -includeNames="$N" "$D/$f" || echo "   REFUSED"
  echo
done

cat <<'NOTE'

Observed (zlint v3.7.1-20-g1007b1d5):

a trust-store subordinate CA, CA:TRUE, EKU serverAuth + clientAuth +
OCSPSigning, notBefore 2017-10-18
e_ocsp_id_pkix_ocsp_nocheck_ext_not_included_server_auth error

zlint's own fixture o1s0ep0a0nc0.pem, CA:FALSE, EKU OCSPSigning alone, no
nocheck e_ocsp_id_pkix_ocsp_nocheck_ext_not_included_server_auth error

Correct: NA on the first, error on the second. The control is the lint's own
test case and its expectation is lint.Error; nothing here disputes it.

The remaining 13 are end-entity certificates and are the population the lint
is for. The EKU sets behind the CA firings are ordinary issuing-CA sets:
serverAuth + clientAuth +
OCSPSigning (141), and Microsoft-extended sets carrying clientAuth,
emailProtection and OCSPSigning (127 across two shapes).

The lint sets OverrideFrameworkFilter: true, so util.IsServerAuthCert does not
narrow it either — the guard above is the whole population test.

The lint's 32-case fixture matrix varies OCSPSigning, serverAuth,
emailProtection, anyEKU and nocheck, and every case is an end-entity
certificate. No fixture asserts what the lint should do with a CA, so the
narrowing below breaks no test.

Fix: `return util.IsDelegatedOCSPResponderCert(c) && !util.IsCACert(c)`, or
add the basicConstraints test to util.IsDelegatedOCSPResponderCert itself,
where the name already claims more than HasEKU delivers. NOTE
