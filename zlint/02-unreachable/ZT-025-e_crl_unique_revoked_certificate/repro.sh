#!/bin/bash
# No third. Its own test (TestUniqueRevokedCertificate) asserts lint.Warn
# for the duplicate case, so this is deliberate, not a slip — which is what
# makes it a naming/status question for upstream rather than a one-line fix.
# ./positive/ZT-025-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
N=e_crl_unique_revoked_certificate

echo "== real-world CRL with a repeated revoked-certificate serial number"
echo "   positive/ZT-025-crl-duplicate-revoked-serial.crl (Mozilla CA incident bug 1943379, sha256 60914b68b65a...)"
echo "   11,327 revokedCertificates entries; serial 5a6e9bb44e7ae6eb95a07e20a37b6d07 appears twice"
"$Z" -format der -includeNames="$N" "$D/positive/ZT-025-crl-duplicate-revoked-serial.crl" || echo "   REFUSED"

cat <<'NOTE'

Observed (zlint v3.7.1-20-g1007b1d5):

  {"e_crl_unique_revoked_certificate":{"result":"warn",
   "details":"Revoked certificates list contains duplicate serial number: 5a6e9bb44e7ae6eb95a07e20a37b6d07"}}

The lint fires — the property is real and the class sees it — but it can only
ever return Pass or Warn. The Execute body quoted at the top of this script is
copied in full: no lint.Error and no lint.Fatal literal appears anywhere in
it.

reachable Error branch (RFC 5280 §5.1.2.6 and CABF BRs 7.2.1 are both silent
on whether a CRL MUST or merely SHOULD avoid a duplicate revoked-certificate
entry, which is exactly the citation a maintainer needs to supply), or the
class is renamed w_crl_unique_revoked_certificate to match the status it
actually returns. What is not in question is that, as shipped, an e_-prefixed
class that structurally cannot return Error should not be counted as an
unmeasured gap when it stays silent on a CRL without the duplicate — it was
never going to answer past Warn on any input.

Same family as ZT-022 (a lint whose own comparison can never take the Error
branch) and ZT-023 (lints unreachable by construction): the common shape is a
NOTE
