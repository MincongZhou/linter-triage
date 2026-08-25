#!/bin/bash
# ZT-063 — e_subscribers_crl_distribution_points_are_http reports a certificate that has no cRLDistributionPoints extension, under a lint about the URI scheme, alongside the lint that already reports the absence. Description: "cRLDistributionPoints SHALL have URI scheme HTTP." Citation:    7.1.2.3.b  The two branches of Execute are written differently and only one of them guards against an empty list:  if (IsMultipurpose(c) || IsStrict(c)) && httpCount != len(c.CRLDistributionPoints) { ... }                                  // vacuous when the list is empty if IsLegacy(c) && httpCount == 0 { ... }                                  // fires when the list is empty  So a Legacy S/MIME certificate carrying no cRLDistributionPoints at all draws an error from this lint, with the details "SMIME certificate contains no HTTP URI schemes as CRL distribution points" -- a sentence about a certificate that has distribution points, which this one does not.  e_subscribers_shall_have_crl_distribution_points already reports it, correctly and with the right message, so one missing extension is two findings whose repair is the same edit. Two branches of one function, one guarded and one not, is the "one of anything is a slip" test from the reporting skill. Certificates: zlint's own fixtures, unmodified.
set -u
Z=${ZLINT:-$HOME/.local/bin/zlint}
D=$(dirname "$0")
L=e_subscribers_crl_distribution_points_are_http,e_subscribers_shall_have_crl_distribution_points
echo "zlint: $($Z -version 2>&1 | head -1)"
echo

for c in positive/ZT-063-legacy-no-crldp negative/ZT-063-control-legacy-with-crldp; do
  f="$D/$c.pem"
  n=$(openssl x509 -in "$f" -noout -text | grep -c "X509v3 CRL Distribution")
  echo "$c  (cRLDistributionPoints extensions: $n)"
  $Z -includeNames=$L "$f" 2>/dev/null | tr ',' '\n' | sed 's/^/    /'
  echo
done

echo "observed: two errors for one missing extension, and the scheme lint's"
echo "          message describes distribution points the certificate has none of"
echo "correct : one error, from e_subscribers_shall_have_crl_distribution_points"
echo "fix     : guard the Legacy branch on the list being non-empty, as its"
echo "          sibling branch already is:"
echo "              if IsLegacy(c) && len(c.CRLDistributionPoints) > 0 && httpCount == 0"
