#!/bin/bash
# XT-002 — a CA certificate whose keyUsage omits keyCertSign is typed as a
# Subscriber Certificate, so x509lint applies the leaf profile to it and
# skips the CA profile entirely. One of the skipped checks is the check for
# exactly this defect, which makes that check unreachable.
# ./positive/XT-002-repro.sh /path/to/x509lint
set -u
X="${1:-x509lint}"
D="$(cd "$(dirname "$0")" && pwd)"

echo "== SUBJECT: a CA certificate whose keyUsage omits keyCertSign"
openssl x509 -in "$D/positive/XT-002-ca-without-keycertsign.pem" -noout -ext basicConstraints,keyUsage 2>/dev/null
"$X" "$D/positive/XT-002-ca-without-keycertsign.pem" || echo FAILED

echo
echo "== CONTROL: the same shape, keyUsage asserting keyCertSign"
openssl x509 -in "$D/positive/XT-002-ca-with-keycertsign.pem" -noout -ext basicConstraints,keyUsage 2>/dev/null
"$X" "$D/positive/XT-002-ca-with-keycertsign.pem" || echo FAILED

cat <<'NOTE'

Both files are zlint's own fixtures. Both are non-self-issued intermediates
whose basicConstraints is critical with CA:TRUE. They differ in the keyUsage
bits and in nothing else that bears on typing.

Observed (x509lint at commit 103c92f):

subject I: Checking as leaf certificate E: No Subject alternative name
extension control I: Checking as intermediate CA certificate

Correct: both are CA certificates and must be checked as such. No document
requires a subjectAltName of a CA certificate; the Baseline Requirements
profile it in the CA table of 7.1.2.10, where subjectAltName does not appear.

MECHANISM

checks.c:1893 GetType() derives the profile from OpenSSL:

        int ca = X509_check_ca(x509);
        ...
        if (!ca) return SubscriberCertificate;

and OpenSSL's check_ca() rejects on keyUsage before it ever reads
basicConstraints:

        static int check_ca(const X509 *x) {
            if (ku_reject(x, KU_KEY_CERT_SIGN))   /* keyUsage present and
                return 0;                            omitting keyCertSign */
            ...

XT-002-check-ca.c executes that claim rather than reading it:

cc -o check-ca XT-002-check-ca.c -lcrypto ./check-ca
positive/XT-002-ca-without-keycertsign.pem
positive/XT-002-ca-with-keycertsign.pem

        positive/XT-002-ca-without-keycertsign.pem   bc.CA=TRUE  keyCertSign=no   X509_check_ca()=0
        positive/XT-002-ca-with-keycertsign.pem      bc.CA=TRUE  keyCertSign=yes  X509_check_ca()=1

WHAT THE MISTYPING COSTS

Every check keyed on `type != SubscriberCertificate` is skipped for such a
certificate -- the whole CA profile:

checks.c:1643 ERR_NO_BASIC_CONSTRAINTS checks.c:1652
ERR_BASIC_CONSTRAINTS_NOT_CRITICAL checks.c:1656 ERR_CA_CERT_NOT_CA
checks.c:1521 WARN_KEY_USAGE_NO_CERT_OR_CRL_SIGN checks.c:1882 the
subjectKeyIdentifier requirement checks.c:1473, 1481, 2293, 2302

and every check keyed on `type == SubscriberCertificate` is applied instead:
subjectAltName, certificatePolicies, authorityInformationAccess, revocation
over HTTP, the 39-month ceiling, and the DV/OV subject rules. All spurious.

THE UNREACHABLE CHECK

checks.c:1521 is the check for this very defect:

        if (type != SubscriberCertificate && (bits & (KU_KEY_CERT_SIGN|KU_CRL_SIGN)) == 0)
                SetWarning(WARN_KEY_USAGE_NO_CERT_OR_CRL_SIGN);

Firing needs keyUsage present and asserting neither bit. That is a subset of
"keyUsage present and omitting keyCertSign", which is precisely what makes
X509_check_ca() return 0 and the left conjunct false. The block is reached only
when the keyUsage extension is present, so the "keyUsage absent" escape does not
apply.

Executed, not read: `W: Key usage doesn't have keyCertSign or cRLSign` is
The subject file above is a certificate that satisfies the right conjunct and
does not produce it.

This is the shape where a gate reads the field its own rule polices.

REACH (the corpus, 21,802 certificates, x509lint 103c92f)

  12,825  carry basicConstraints CA:TRUE
      83  of those are typed SubscriberCertificate by GetType()
39 of the 83 draw at least one leaf-profile finding that cannot apply: 19 No
Subject alternative name extension 18 No CRL or OCSP over HTTP 11 Subject with
organizationName, givenName or surname but without stateOrProvince or
localityName 9 Domain validated certificate with organizationName 8 The
certificate is valid for longer than 39 months 3 No policy extension 2 no
authorityInformationAccess extension 4 of the 83 are publicly-trusted CCADB
intermediates, not fixtures

  All 83 escape the CA profile, whether or not they draw a leaf finding.

One check does survive, by accident: ERR_BASIC_CONSTRAINTS_NO_CERT_SIGN_PATHLEN
(checks.c:1672) sits outside the `type != SubscriberCertificate` guard and fires
24 times here -- but only on a CA certificate that carries a
pathLenConstraint. A CA:TRUE with no pathlen and no keyCertSign is reported by
nothing.

FIX

Derive the profile from basicConstraints rather than from X509_check_ca(),
which answers "may this certificate sign certificates", a different question:

        BASIC_CONSTRAINTS *bc = X509_get_ext_d2i(x509, NID_basic_constraints, NULL, NULL);
        int ca = bc != NULL && bc->ca;

That makes ERR_CA_CERT_NOT_CA and WARN_KEY_USAGE_NO_CERT_OR_CRL_SIGN reachable,
which is what they were written for. If X509_check_ca()'s leniency toward the
old pre-basicConstraints conventions is wanted, keep it as a widening --
`ca = (bc && bc->ca) || X509_check_ca(x509)` -- never as the sole test.
NOTE
