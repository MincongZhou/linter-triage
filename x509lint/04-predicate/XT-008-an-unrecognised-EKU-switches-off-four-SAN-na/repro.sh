#!/bin/bash
# XT-008 — in x509lint, an EKU OID the linter does not recognise switches
# off four SubjectAltName name-type prohibitions. The two certificates here
# differ in exactly one byte. Both carry a SAN whose only entry is an
# otherName. The base asserts EKU id-kp-codeSigning (1.3.6.1.5.5.7.3.3); the
# variant asserts 1.3.6.1.5.5.7.3.99, an unassigned OID of identical encoded
# length. No length octet changes anywhere in the certificate.
# ./positive/XT-008-repro.sh /path/to/x509lint
set -u
X="${1:-x509lint}"
D="$(cd "$(dirname "$0")" && pwd)"

echo "== base: EKU = { 1.3.6.1.5.5.7.3.3 codeSigning }"
"$X" "$D/positive/XT-008-otherName-san-recognised-eku.pem" || echo FAILED
echo
echo "== variant: EKU = { 1.3.6.1.5.5.7.3.99 unassigned }"
"$X" "$D/positive/XT-008-otherName-san-unrecognised-eku.pem" || echo FAILED
echo
echo "== the two DERs differ in one byte:"
cmp -l <(openssl x509 -in "$D/positive/XT-008-otherName-san-recognised-eku.pem" -outform DER) \
       <(openssl x509 -in "$D/positive/XT-008-otherName-san-unrecognised-eku.pem" -outform DER) \
  || true

cat <<'NOTE'

Observed (x509lint at commit 103c92f):

  base     E: Invalid type in SAN entry
  variant  W: Unknown extended key usage        <- the SAN error is gone

Mechanism, checks.c CheckSAN():

    if (GetBit(warnings, WARN_UNKNOWN_EKU)
        && !GetBit(cert_info, CERT_INFO_SERV_AUTH)
        && !GetBit(cert_info, CERT_INFO_ANY_EKU))
    {
        name_type_allowed[GEN_OTHERNAME] = SAN_TYPE_ALLOWED;
        name_type_allowed[GEN_X400]      = SAN_TYPE_ALLOWED;
        name_type_allowed[GEN_EDIPARTY]  = SAN_TYPE_ALLOWED;
        name_type_allowed[GEN_URI]       = SAN_TYPE_ALLOWED;
    }

WARN_UNKNOWN_EKU is set by the else-branch of the EKU classification loop in
CheckEKU(), i.e. by any OID absent from x509lint's own eight-entry table.
CheckEKU runs before CheckSAN (checks.c:2279 and 2281), so the flag is set in
time.

A correct tool would decide the permitted SAN name types from something the
certificate asserts, not from the absence of an OID from the linter's table:
the same certificate must not be checked less thoroughly because an OID was
added that the linter has never heard of. NOTE
