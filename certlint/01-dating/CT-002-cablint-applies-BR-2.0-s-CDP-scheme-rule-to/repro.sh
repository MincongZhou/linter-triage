#!/bin/bash
# CT-002 — cablint applies the BR 2.0 "scheme of each MUST be http" rule to
# certificates issued before it took effect, though the file defines the
# effective-date constant and date-gates other checks with it. Two
# certificates, because the naive fix breaks the second one:
# positive/CT-002-two-cdp.pem 2021, ldap + http -> over-reported today
# negative/CT-002-control-ldap-only-2009.der 2009, ldap only -> must stay
# reported bash positive/CT-002-repro.sh [/path/to/certlint] Needs ruby and
# certlint's ext/ built.
set -u
CD="${1:-/path/to/certlint}"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "certlint: $CD"
echo

echo "== the certificate =="
openssl x509 -in "$HERE/positive/CT-002-two-cdp.pem" -noout -dates 2>/dev/null | sed 's/^/   /'
echo "   CRL distribution points:"
openssl x509 -in "$HERE/positive/CT-002-two-cdp.pem" -noout -text 2>/dev/null \
    | grep -A6 'CRL Distribution' | grep -E 'URI:' | sed 's/^ */     /'
echo

echo "== cablint =="
( cd "$CD" && ruby -I lib -I ext bin/cablint "$HERE/positive/CT-002-two-cdp.pem" 2>&1 ) | sed 's/^/   /'
echo

echo "== control: 2009 intermediate, ldap:// its only distribution point =="
openssl x509 -inform der -in "$HERE/negative/CT-002-control-ldap-only-2009.der" -noout -subject -dates 2>/dev/null | sed 's/^/   /'
openssl x509 -inform der -in "$HERE/negative/CT-002-control-ldap-only-2009.der" -noout -text 2>/dev/null \
    | grep -A6 'CRL Distribution' | grep -E 'URI:' | sed 's/^ */     /'
( cd "$CD" && ruby -I lib -I ext bin/cablint "$HERE/negative/CT-002-control-ldap-only-2009.der" 2>&1 ) | sed 's/^/   /'
echo "   ^ the ONLY message about its CDP is the line-282 one. Gate line 282 on"
echo "     not_before and cablint goes silent on this certificate entirely."
echo

cat <<'EOF'
============================================================== observed E: CRL
Distribution Point must be an HTTP URL

on a certificate issued 2021-11-24 whose cRLDistributionPoints holds an
ldap:// GeneralName and an http:// GeneralName.

correct   No finding. BR 1.8.7 §7.1.2.b, the version in force at issuance,
          required only that the extension "MUST contain the HTTP URL of the
          CA's CRL service" — which this certificate does. The requirement
          that "the scheme of each MUST be http" arrived with BR 2.0
          (§7.1.2.11.2).

mechanism lib/certlint/cablint.rb:282 reports every DistributionPoint URI
whose scheme is not http, unconditionally. The same file already
          defines BR_2_0_0_EFFECTIVE (line 27) and already date-gates other
          checks against not_before (lines 99, 297, 328).

Four call sites carry this pair of messages, not one: 282 and 285 in the CA
branch, 611 and 614 in the subscriber branch.

fix       NOT the obvious one. This report first proposed "guard line 282 with
          not_before >= BR_2_0_0_EFFECTIVE and leave line 290's at-least-one
          check for earlier issuance". Line 290 is not an at-least-one check
          whatever its message says — its condition is `ca_dps.length == 0`,
          true only for an EMPTY extension.

          The fix is two changes:
            1. gate line 282 (and 611) on not_before >= BR_2_0_0_EFFECTIVE
2. add, for earlier issuance, a branch reporting when NO distributionPoint
carries an http URI — a check the file does not currently contain

sibling   `E: CA Issuers URL must be an HTTP URL` at :321 and :575 has the
same shape and is worse: BR 1.7.0 §7.1.2.2.c and §7.1.2.3.c both make the
caIssuers HTTP URL a SHOULD, so pre-2.0 certificates take an error for
breaching a recommendation.
EOF
