#!/bin/bash
# ZT-045 — the two oldest subscriber validity lints measure the Validity
# Period exclusively, where the Baseline Requirements and zlint's own newer
# validity lints measure it inclusively. The two old lints call it 825 days
# and pass it. All four inputs are certificates neither fabricated nor
# modified: three are zlint's own testdata and the fourth is a real DFN-PKI
# subscriber certificate from Mozilla bug 1651132.
# ./positive/ZT-045-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
N=e_sub_cert_valid_time_longer_than_39_months,e_sub_cert_valid_time_longer_than_825_days,e_tls_server_cert_valid_time_longer_than_398_days

for f in positive/ZT-045-at-the-825-day-ceiling.pem \
         positive/ZT-045-real-825-days-and-one-second.pem \
         positive/ZT-045-at-the-39-month-ceiling.pem \
         negative/ZT-045-control-at-the-398-day-ceiling.pem ; do
  echo "== $f"
  echo "   $(openssl x509 -in "$D/$f" -noout -dates 2>/dev/null | tr '\n' ' ')"
  "$Z" -includeNames="$N" "$D/$f" || echo "   REFUSED"
  echo
done

cat <<'NOTE'

Observed (zlint v3.7.1-20-g1007b1d5):

subCert825DaysOK.pem notBefore 2018-03-02 15:49:34 notAfter 2020-06-04
15:49:34 Validity Period 825 days and 1 second
e_sub_cert_valid_time_longer_than_825_days pass

bug1651132-crtsh574121977 notBefore 2018-07-04 11:05:36 notAfter 2020-10-06
11:05:36 Validity Period 825 days and 1 second
e_sub_cert_valid_time_longer_than_825_days pass

39months.pem notBefore 2017-01-01 00:00:00 notAfter 2020-04-01 00:00:00
Validity Period 39 months and 1 second
e_sub_cert_valid_time_longer_than_39_months pass

eeServerCertValidEqual398.pem notBefore 2020-09-01 00:00:00 notAfter
2021-10-03 23:59:59 Validity Period exactly 398 days
e_tls_server_cert_valid_time_longer_than_398_days pass

Correct: error on the first three, pass on the fourth.

The fourth is the control and it is the whole argument. It is zlint's own
boundary fixture for the *newer* family, and it is built one second shorter
than the two old ones — notAfter at 23:59:59 rather than at the same clock
time as notBefore. Under `GreaterThan` that is exactly 398 x 86,400 seconds
and compliant. The old family's two fixtures are one second past their
ceilings and are asserted `Pass` by
lint_sub_cert_valid_time_longer_than_825_days_test.go:TestSubCertValidTime825Days
and
lint_sub_cert_valid_time_longer_than_39_months_test.go:TestSubCertValidTimeExactly39months.
One project, one clause, two definitions of the boundary.

are passed by this lint — 5 from bug1576013 (DigiCert), 5 from bug1595921
(DigiCert), 4 from bug1651132 (T-Systems / DFN-PKI), and one each from
bug1500621, bug1551363 and bug1654896. Every one was issued between 2018-03-02
and 2020-09-01, so no other zlint lint judges its Validity Period:
e_tls_server_cert_valid_time_longer_than_398_days returns NE below its own
effective date. zlint reports these certificates as conformant on BR 6.3.2.

The population is closed. Both windows ended before 2020-09-01, so no new
issuance can enter either set, and the newer lints already use the inclusive
arithmetic.

Fix: replace both comparisons with the helper the rest of the family uses.

    if util.GreaterThan(c, 825) { Error }

and, for the month-stated ceiling, compare against the calendar instant
inclusively rather than with Before:

    if !c.NotAfter.Before(c.NotBefore.AddDate(0, 39, 0)) { Error }

Both fixtures then need their notAfter moved back one second to keep asserting
what their test names say they assert. NOTE
