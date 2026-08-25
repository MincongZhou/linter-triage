#!/bin/bash
# PT-003 — pkilint applies RFC 5280's explicitText prohibition to
# certificates issued after RFC 6818 withdrew it, and applies RFC 6818's
# replacement to certificates issued before it existed. Neither code carries
# an effective date. bash positive/PT-003-repro.sh
set -u
PY="${1:-$HOME/.venv/linters/bin/python}"
HERE="$(cd "$(dirname "$0")" && pwd)"
C="$HERE/positive/PT-003-visiblestring-post-6818.der"

echo "== the certificate =="
openssl x509 -inform DER -in "$C" -noout -subject -startdate 2>/dev/null | sed 's/^/   /'
echo
echo "== its explicitText encoding, decoded =="
"$PY" - "$C" <<'EOF' | sed 's/^/   /'
import sys from pyasn1.codec.der.decoder import decode from pyasn1_alt_modules
import rfc5280
cert, _ = decode(open(sys.argv[1], "rb").read(), asn1Spec=rfc5280.Certificate())
for ext in cert["tbsCertificate"]["extensions"]:
    if str(ext["extnID"]) != "2.5.29.32":
        continue
    pol, _ = decode(bytes(ext["extnValue"]), asn1Spec=rfc5280.CertificatePolicies())
    for pi in pol:
        pq = pi["policyQualifiers"]
        if not pq.isValue:
            continue
        for q in pq:
            if str(q["policyQualifierId"]) != "1.3.6.1.5.5.7.2.2":
                continue
            un, _ = decode(bytes(q["qualifier"]), asn1Spec=rfc5280.UserNotice())
            if un["explicitText"].isValue:
                print(f"explicitText is a {un['explicitText'].getName()}")
EOF

cat <<'EOF'

============================================================== observed
pkix.rfc5280_certificate_policies_invalid_explicit_text_encoding
          (ERROR) on a certificate issued 2015-07-29 whose explicitText is a
          VisibleString.

correct   No finding. RFC 6818 § 3 (January 2013) replaced the paragraph that
          prohibited it.

mechanism pkilint/pkix/certificate/certificate_extension.py:485, in
CertificatePoliciesUserNoticeValidator.validate:

            if encoding not in ["ia5String", "utf8String"]:
                -> rfc5280_..._invalid_explicit_text_encoding
            if encoding not in ["bmpString", "utf8String", "visibleString"]:
                -> rfc6818_..._invalid_explicit_text_encoding

Both tests run on every certificate. Neither consults notBefore, and the
validator takes no validity_period_start_retriever.

          The two documents do not layer -- the second REPLACES the first:

          RFC 5280 § 4.2.1.4 (May 2008)
            "Conforming CAs SHOULD use the UTF8String encoding for
             explicitText, but MAY use IA5String. Conforming CAs MUST NOT
             encode explicitText as VisibleString or BMPString."

          RFC 6818 § 3 (January 2013), under "This paragraph is replaced with"
            "Conforming CAs SHOULD use the UTF8String encoding for
explicitText. VisibleString or BMPString are acceptable but less preferred
alternatives. Conforming CAs MUST NOT encode
             explicitText as IA5String."

So from 2013-01-01 the two encodings the rfc5280 code reports are acceptable,
and the one it permits is prohibited. Applying both unconditionally means
every certificate with an explicitText is judged against a rule that was
withdrawn, a rule that did not yet exist, or both.

fix Gate each code on notBefore against 2013-01-01 -- the rfc5280 test below
it, the rfc6818 test from it. The framework already supports
          this; sibling validators take a validity_period_start_retriever.

          is IssuedBetween(2008-05-01, 2013-01-01) and
          rfc6818/e_ext_cert_policy_explicit_text_ia5_string is
          IssuedFrom(2013-01-01) -- so between them they cover every
          certificate and never both fire on one.
EOF
