#!/bin/bash
# ZT-030 — e_sub_cert_or_sub_ca_using_sha1 fires on a root, which its own
# Description excludes. lint_sub_cert_or_sub_ca_using_sha1.go: Description:
# "CAs MUST NOT issue any new Subscriber certificates or Subordinate CA
# certificates using SHA-1 after 1 January 2016" func (l *sigAlgTestsSHA1)
# CheckApplies(c *x509.Certificate) bool { return true } The Description
# names two certificate kinds and BR § 7.1.3 scopes the requirement the same
# way. Unlike ZT-001 and ZT-029 this is not a house pattern with a guarded
# sibling: there is no second lint for this question to compare against. It
# is a one-line disagreement between a lint's stated scope and its actual
# guard. Case: zlint's own fixture, self-signed, CA:TRUE, notBefore
# 2016-04-25.
set -u
Z=${ZLINT:-$HOME/.local/bin/zlint}
D=$(dirname "$0")
echo "zlint: $($Z -version 2>&1 | head -1)"
echo
echo "-- observed --"
$Z -includeNames=e_sub_cert_or_sub_ca_using_sha1 "$D/positive/ZT-030-sha1-root.pem" 2>/dev/null
openssl x509 -in "$D/positive/ZT-030-sha1-root.pem" -noout -subject -issuer 2>/dev/null | sed 's/^/  /'
openssl x509 -in "$D/positive/ZT-030-sha1-root.pem" -noout -text 2>/dev/null \
  | grep -A1 'Basic Constraints' | tail -1 | sed 's/^ */  /'
echo
echo "  subject equals issuer and CA is TRUE: this is a root."
echo
echo "observed: error, on a root certificate"
echo "correct : NA"
echo "fix     : CheckApplies should be !util.IsRootCA(c)"
