#!/bin/bash
# CT-023 — certlint's "Generalized Time before 2050" has no lower bound, so
# it demands UTCTime for years UTCTime cannot express. bash
# positive/CT-023-repro.sh [/path/to/certlint] Needs ruby and certlint's
# ext/ built.
set -u
CD="${1:-/path/to/certlint}"
HERE="$(cd "$(dirname "$0")" && pwd)"
echo "certlint: $CD"; echo

echo "== the certificate's time fields =="
openssl asn1parse -inform der -in "$HERE/positive/CT-023-generalizedtime-year-0001.der" \
    | grep -E 'UTCTIME|GENERALIZEDTIME' | sed 's/^/   /'
echo

echo "== certlint =="
( cd "$CD" && ruby -I lib -I ext bin/certlint "$HERE/positive/CT-023-generalizedtime-year-0001.der" 2>&1 ) \
    | grep -i 'time' | sed 's/^/   /'
echo

echo "== the range UTCTime can express, per RFC 5280 4.1.2.5.1 =="
echo "   'Where YY is greater than or equal to 50, the year SHALL be"
echo "    interpreted as 19YY; and where YY is less than 50, the year SHALL"
echo "    be interpreted as 20YY.'  ->  1950 through 2049, and nothing else."
echo

cat <<'EOF'
============================================================== observed E:
Generalized Time before 2050

on a certificate whose notBefore is the GeneralizedTime 00010101000000Z — the
year 1.

correct   No finding. The message means "this should have been a UTCTime", and
RFC 5280 4.1.2.5.1 gives UTCTime a two-digit year interpreted as 1950-2049.
The year 1 is not representable as a UTCTime at all, so the correction the
message names does not exist. RFC 5280 4.1.2.5
          requires GeneralizedTime for "dates in 2050 or later"; a date before
1950 is outside both halves of the rule and the clause says nothing about it.

mechanism lib/certlint/certlint.rb:291-293, inside the time-field traverse:

              if value[0..3] < '2050'
                messages << 'E: Generalized Time before 2050'
              end

A string comparison with an upper bound and no lower bound. '0001' sorts below
'2050' exactly as '2049' does, and the check cannot
          tell "should have been UTCTime" from "cannot be a UTCTime".

fix       Bound it below:

              if value[0..3] < '2050' && value[0..3] >= '1950'

A date outside 1950-2049 in either direction wants a different message — it is
a validity-range question, not an encoding one.

note      Third implementation, second to get it wrong.
EOF
