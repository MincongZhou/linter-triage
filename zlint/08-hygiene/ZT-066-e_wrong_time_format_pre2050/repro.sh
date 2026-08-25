#!/bin/bash
# ZT-066 - e_wrong_time_format_pre2050 names a correction that cannot be
# made. The lint reports a GeneralizedTime used for a date before 2050,
# citing RFC 5280 4.1.2.5: "Certificates valid through the year 2049 MUST be
# encoded in UTC time". That is right for a date UTCTime can express -- and
# UTCTime carries a two-digit year, so RFC 5280 4.1.2.5.1 fixes its range at
# **1950 through 2049**. A notAfter of year 1 is before 2050 and outside
# UTCTime entirely. The lint demands an encoding that cannot represent the
# value, so a CA following the finding has nowhere to go: the certificate is
# defective, and not in the way the finding says. zlint's Execute compares
# `t.Before(util.GeneralizedDate)` with no lower bound. The rule here gained
# one for exactly this certificate. ./positive/ZT-066-repro.sh
# /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
C="$D/positive/ZT-066-notafter-year-one.pem"

echo "== the certificate's validity, and the encoding of notAfter"
openssl x509 -in "$C" -noout -dates 2>/dev/null
echo -n "   notAfter is encoded as GeneralizedTime: "
openssl asn1parse -in "$C" 2>/dev/null | grep -m1 GENERALIZEDTIME | sed 's/^ *//'

echo
echo "== what the lint says"
"$Z" -includeNames e_wrong_time_format_pre2050 "$C"

echo
echo "== the range UTCTime can express, RFC 5280 4.1.2.5.1"
echo "   1950-01-01 through 2049-12-31. Year 1 is not in it."

echo
echo "observed  error, telling the CA to encode year 1 as UTCTime."
echo "correct   this lint should not fire below 1950. The certificate is"
echo "          defective -- a notAfter of year 1 is nonsense -- but the"
echo "          defect is the value, and no encoding change repairs it."
