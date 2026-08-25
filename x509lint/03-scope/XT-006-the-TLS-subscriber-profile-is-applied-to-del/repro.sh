#!/bin/bash
# XT-006 — x509lint applies the TLS Baseline Requirements subscriber profile
# to a delegated OCSP responder certificate, and demands three extensions
# that BR §7.1.2.8.2 forbids or discourages for that profile.
# ./positive/XT-006-repro.sh /path/to/x509lint
set -u
X="${1:-x509lint}"
D="$(cd "$(dirname "$0")" && pwd)"

echo "== a conforming delegated OCSP responder"
echo "   (zlint's own fixture ocsp_cert_ok1.pem: EKU = OCSP Signing only,"
echo "    id-pkix-ocsp-nocheck present, no CRLDP, no certificatePolicies, no AIA)"
openssl x509 -in "$D/positive/XT-006-ocsp-responder-conforming.pem" -noout \
  -ext extendedKeyUsage,basicConstraints,keyUsage 2>/dev/null
echo
"$X" "$D/positive/XT-006-ocsp-responder-conforming.pem" || echo FAILED

cat <<'NOTE'

Observed (x509lint at commit 103c92f):

E: No policy extension E: No CRL or OCSP over HTTP E: no
authorityInformationAccess extension I: Checking as leaf certificate

Correct: no error. CA/Browser Forum Baseline Requirements §7.1.2.8.2, "OCSP
Responder Extensions", profiles exactly this certificate:

  certificatePolicies        SHOULD NOT
  authorityInformationAccess NOT RECOMMENDED   (§7.1.2.8.3 gives the reason)
  crlDistributionPoints      MUST NOT          (via §7.1.2.11.2)
  subjectAltName             MUST NOT

The third error cannot be satisfied at all without breaching the profile: the
only two carriers of a revocation pointer are the CRL distribution point,
which MUST NOT be present, and authorityInfoAccess, which is NOT RECOMMENDED.

Independent confirmation that this file is conforming: it is zlint's own
positive fixture, and zlint's test table declares it Pass for
e_ocsp_cert_cdp_forbidden and e_ocsp_cert_cp_forbidden -- lints that exist
because the absences x509lint reports as errors are what the profile requires.

Mechanism, checks.c:

  GetType()               returns SubscriberCertificate for anything
                          X509_check_ca() does not call a CA (checks.c:1922-1924).
  CheckPolicy()           SetError(ERR_NO_POLICY)      if type == SubscriberCertificate
                          (checks.c:909)
  CheckAIA()              SetError(ERR_NO_AIA)         if type == SubscriberCertificate
                          (checks.c:1351)
  CheckRevocationOverHTTP SetError(ERR_NO_REVOCATION_HTTP) if type == SubscriberCertificate
                          (checks.c:1375)

x509lint's only profile axis is leaf / intermediate CA / root CA. It has no
notion of the *purpose* profile the Baseline Requirements impose on a leaf, so
every requirement written for a TLS subscriber certificate is applied to
delegated OCSP responders, and to S/MIME, timestamping and code signing
certificates, which the Forum profiles in other documents or not at all.

Reach over the corpus (21,802 certificates, x509lint 103c92f):

  82 delegated OCSP responders reach these checks, of which
     79 draw "no authorityInformationAccess extension"
     71 draw "No CRL or OCSP over HTTP"
     68 draw "No policy extension"
     14 draw "No Subject alternative name extension"  (those also carrying
        anyExtendedKeyUsage or emailProtection, which is what sets bSanRequired)

  Of the 191 certificates issued on or after 2012-07-01 that draw
the extended key usages are: 62 OCSP Signing, 57 no EKU at all, 51 E-mail
Protection, 7 Time Stamping, 4 anyExtendedKeyUsage, 2 Code Signing. Not one is
a TLS server certificate.

Fix (one line, narrowest form): in CheckPolicy(), CheckAIA() and
CheckRevocationOverHTTP(), require the certificate to be in the TLS server
profile rather than merely not a CA -- e.g. gate each on
GetCertInfo(CERT_INFO_SERV_AUTH) as well as type == SubscriberCertificate. The
general form is a purpose axis derived from extKeyUsage, set once in CheckEKU()
and consulted by every check whose citation is a Baseline Requirements clause.
NOTE
