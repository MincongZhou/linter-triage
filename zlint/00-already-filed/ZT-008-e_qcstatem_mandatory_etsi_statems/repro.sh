#!/bin/bash
# ZT-008 - e_qcstatem_mandatory_etsi_statems reports a clause that governs
# EU qualified certificates against certificates that are not one. The
# lint's Citation is "ETSI EN 319 412 - 5 V2.2.1 (2017 - 11) / Section 5",
# and that section states exactly one requirement: QCS-5-01: EU qualified
# certificates shall include QCStatements in accordance with table 2. Table
# 2 marks esi4-qcStatement-1 (QcCompliance) Mandatory. The lint's
# CheckApplies does not ask whether the certificate is an EU qualified
# certificate. It asks util.IsAnyEtsiQcStatementPresent -- whether the
# qcStatements extension carries any ETSI ESI statement at all -- and the
# lint's own Description says so. But several of those statements are
# defined for use in non-qualified certificates: EN 319 412-5 4.2.3 says
# QcType used on its own "indicates that it is used for the purposes of ...
# non-qualified certificates", and QcPDS and QcRetentionPeriod are generic
# statements EN 319 411-1 applies to non-qualified certificates as well. The
# predicate is also circular. QcCompliance is *how* a certificate claims EU
# qualified status, so requiring it because it is absent assumes the answer.
# What a certificate claims qualified status with, apart from QcCompliance,
# is an EN 319 411-2 policy identifier -- the arc 0.4.0.194112.1., every
# policy under which is a policy for a qualified certificate. EN 319 411-1's
# arc, 0.4.0.2042.1., is the NON-qualified series: NCP, LCP, EVCP, DVCP,
# OVCP, PTC. This was adjudicated in 2020. Mozilla bug 1625421 reported 21
# FNMT-RCM precertificates for this lint; FNMT suspended issuance from that
# CA on 2020-03-28 while it investigated; the reviewer concluded "the use of
# these QCStatements does not imply a Qualified certificate, and thus does
# not imply a violation of ETSI EN 319 412-5 / ETSI EN 319 411-2", filed
# zlint issue 424, and the bug was RESOLVED/INVALID. The lint is unchanged.
# ./positive/ZT-008-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
SUBJECT="$D/positive/ZT-008-fnmt-ovcp-non-qualified.der"        # OVCP, non-qualified
CONTROL="$D/negative/ZT-008-control-qualified-policy.pem"       # QCP-n, qualified

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
openssl x509 -inform der -in "$SUBJECT" -out "$TMP/subject.pem" 2>/dev/null
SUBJECT_PEM="$TMP/subject.pem"

echo "== the two certificates"
echo "   subject: FNMT-RCM 'AC Componentes Informaticos' -- the CA and the"
echo "            profile of Mozilla bug 1625421, from "
echo "   control: pdsAllHttps.pem -- zlint's OWN test fixture."
echo "   Neither carries QcCompliance. Both carry other ETSI ESI statements."
for f in "$SUBJECT_PEM" "$CONTROL"; do
  printf '   %-42s issuer %s\n' "$(basename "$f")" \
    "$(openssl x509 -in "$f" -noout -issuer | sed 's/issuer=//' | cut -c1-58)"
done

echo
echo "== the certificate policy each asserts, which is the whole question"
for f in "$SUBJECT_PEM" "$CONTROL"; do
  printf '   %-42s ' "$(basename "$f")"
  openssl x509 -in "$f" -noout -text \
    | grep -oE '0\.4\.0\.(194112|2042)\.1\.[0-9]+' | sort -u | tr '\n' ' '
  echo
done
echo "   0.4.0.2042.1.7  is OVCP, from EN 319 411-1  -- NOT qualified"
echo "   0.4.0.194112.1.1 is QCP-n, from EN 319 411-2 --     qualified"

echo
echo "== what the lint says about each"
for f in "$SUBJECT_PEM" "$CONTROL"; do
  printf '   %-42s ' "$(basename "$f")"
  "$Z" -includeNames e_qcstatem_mandatory_etsi_statems "$f"
done

echo
echo "   observed  error on both, with identical details."
echo "   correct   pass on the OVCP certificate, which QCS-5-01 does not"
echo "             govern; error on the QCP-n one, which it does."
echo
echo "   The two differ only in the arc of the policy they assert, and the"
echo "   lint's verdict does not move -- which is the mechanism: CheckApplies"
echo "   never reads certificatePolicies at all."
echo
echo "== fix"
echo "   Gate CheckApplies on the certificate claiming EU qualified status:"
echo "   an EN 319 411-2 policy identifier (arc 0.4.0.194112.1.), which is"
echo "   the only claim available to a certificate that lacks QcCompliance."
