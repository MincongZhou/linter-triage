#!/bin/bash
# ZT-082 — four lints whose own Descriptions say "Subscriber certificates"
# are applied to a delegated OCSP responder, which BR 7.1.2.8 gives a
# different profile: subjectAltName MUST NOT, and the subject follows
# 7.1.2.10.2, CA Certificate Naming.
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
LINTS="e_ext_san_missing e_subject_common_name_not_from_san e_sub_cert_locality_name_must_appear e_sub_cert_province_must_appear e_ocsp_cert_cp_forbidden e_ocsp_id_pkix_ocsp_nocheck_ext_not_included_server_auth"

show() {
  "$Z" "$1" 2>/dev/null | python3 -c '
import json, sys
d = json.load(sys.stdin)
for k in sys.argv[1:]:
    print("      %5s  %s" % (d[k]["result"], k))
' $LINTS
}

echo "== SUBJECT: a delegated OCSP responder — extendedKeyUsage is id-kp-OCSPSigning and nothing else"
openssl x509 -in "$D/positive/ZT-082-delegated-ocsp-responder.pem" -noout -subject -ext extendedKeyUsage 2>/dev/null \
  | grep -v "^X509v3\|^$" | sed 's/^/      /'
show "$D/positive/ZT-082-delegated-ocsp-responder.pem"

echo
echo "== CONTROL: a TLS subscriber certificate from the same collection"
show "$D/negative/ZT-082-control-subscriber-certificate.pem"

cat <<'NOTE'

Observed: four errors against a delegated OCSP responder, from lints whose own
          Descriptions begin "Subscriber certificates" and "Subscriber
          Certificate", citing BRs 7.1.4.2.1 and 7.1.4.2.2.
Correct: NA. BR 7.1.2.8 is the OCSP Responder Certificate Profile, and it
answers all four questions differently:

            subjectAltName    MUST NOT be present   (7.1.2.8.2)
            subject           see 7.1.2.10.2, CA Certificate Naming
                                                    (7.1.2.8, subject row)

e_ext_san_missing reports the ABSENCE of an extension this certificate's
profile forbids it to have, and e_subject_common_name_not_from_san asks a
commonName to come from SAN entries the profile forbids it to carry --
unsatisfiable, not merely inapplicable. The two naming lints read the
subscriber clause where 7.1.2.8 names the CA one.

The control shows those lints applying and passing on an ordinary TLS
subscriber certificate, so this is the population and not the predicate. One
column reads NE there rather than pass: e_subject_common_name_not_from_san
carries IneffectiveDate CABFBRs_1_8_0_Date and the control is recent, while
the responder is old enough for the lint to be in force. That is the lint
dating itself correctly and is unrelated to the finding.

THE MECHANISM

    lint_ext_san_missing.go:50                 return !util.IsCACert(c)
    lint_subject_common_name_not_from_san.go   CommonName != "" && !IsCACert(c)
    lint_sub_cert_locality_name_must_appear.go return util.IsSubscriberCert(c)
    lint_sub_cert_province_must_appear.go      return util.IsSubscriberCert(c)

    util/ca.go:43  func IsSubscriberCert(c) { return !IsCACert(c) && !IsSelfSigned(c) }

A delegated responder is not a CA and is not self-signed, so it satisfies both.
"Not a CA certificate" is being used to mean "a Subscriber Certificate", and the
BRs define a third thing.

**zlint already has the predicate**, four lines below the one being used:

util/ca.go:47 // IsDelegatedOCSPResponderCert returns true if the //
id-kp-OCSPSigning EKU is set
    util/ca.go:50  func IsDelegatedOCSPResponderCert(cert) bool {
                       return HasEKU(cert, x509.ExtKeyUsageOcspSigning) }

**Exactly one lint in the tree calls it**:
lint_ocsp_id_pkix_ocsp_nocheck_ext_not_included_server_auth.go. Four lints on
the responder profile exist -- cdp_forbidden, cp_forbidden, invalid_ku,
nocheck
-- so the profile is known; the subscriber lints simply do not exclude it.

Note that IsDelegatedOCSPResponderCert is INCLUSIVE (the EKU contains
OCSPSigning) where BR 7.1.2.8.5 makes the profile exclusive (id-kp-OCSPSigning
MUST be present and any other value MUST NOT). Either reading excludes the
certificate here, whose EKU is exactly id-kp-OCSPSigning.

REACH

One certificate over the corpus (21,802), drawing four errors -- the corpus holds
73 delegated responders and most carry no commonName or place attributes to
fault. Reach is small; the mechanism is not, because it decides which profile a
whole certificate class is judged against.

FIX

Add `&& !util.IsDelegatedOCSPResponderCert(c)` to each of the four CheckApplies,
or narrow IsSubscriberCert itself -- the latter reaches every lint that uses
it and is the reason to prefer it.

rules corrected on 2026-08-22 (26 findings over the same corpus). Three
implementations, one confusion: "not a CA" is not "a Subscriber Certificate".
NOTE
