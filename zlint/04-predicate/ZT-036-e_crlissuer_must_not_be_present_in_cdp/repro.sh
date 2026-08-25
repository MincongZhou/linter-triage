#!/bin/bash
# ZT-036 - e_crlissuer_must_not_be_present_in_cdp cannot see the shape its
# body checks. The guard is `c.CRLDistributionPoints != nil`, which zcrypto
# populates only from fullName URIs. Execute re-decodes the raw extension
# and errors on a cRLIssuer or a reasons field. A DistributionPoint carrying
# only reasons has no fullName, so nothing is extracted, the slice stays
# nil, and the lint returns NA - the shape the body catches is the shape the
# guard filters out. util.IsExtInCert(c, util.CrlDistOID) reaches it.
# Certificate: zlint's own fixture v3/testdata/crlIncomlepteDp.pem,
# unmodified. notBefore 2055-12-01, well past SC62EffectiveDate, so NA is
# the guard and not the date. e_distribution_point_incomplete is included to
# show the loop is reached at all. ./positive/ZT-036-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"

"$Z" -includeNames=e_crlissuer_must_not_be_present_in_cdp,e_distribution_point_incomplete \
     "$D/positive/ZT-036-cdp-reasons-only.pem" || echo FAILED
echo
echo "observed  e_crlissuer_must_not_be_present_in_cdp NA"
echo "correct   error - BR 7.1.2.11.2 forbids the reasons field"
