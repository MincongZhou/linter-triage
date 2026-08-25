#!/bin/bash
# ZT-035 - e_distribution_point_incomplete gates the general rule behind a
# special case. RFC 5280 4.2.1.13: a DistributionPoint MUST contain either
# distributionPoint or cRLIssuer. The lint errors only when
# `dp.Reason.BitLength != 0` as well, which implements the reasons-only
# special case and suppresses the general rule. A DistributionPoint with no
# fields at all has BitLength 0 and passes. Certificate: fabricated.
# RSA-2048 leaf from a throwaway CA carrying a raw 2.5.29.31 extension whose
# value is 30 02 30 00 - one empty DistributionPoint.
# ./positive/ZT-035-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"

"$Z" -includeNames=e_distribution_point_incomplete "$D/positive/ZT-035-empty-distribution-point.pem" || echo FAILED
echo
echo "observed  pass"
echo "correct   error - neither distributionPoint nor cRLIssuer is present"
