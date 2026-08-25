#!/bin/bash
# ZT-013 — the two superseded subscriber validity-period lints never stop
# applying, though each names the day it stopped applying in its own
# Description.
# lints/cabf_br/lint_sub_cert_valid_time_longer_than_39_months.go:
# Description: "Subscriber Certificates issued after 1 July 2016 but prior
# to 1 March 2018 MUST have a Validity Period no greater than 39 months.",
# EffectiveDate: util.SubCert39Month, // 2016-07-02
# lints/cabf_br/lint_sub_cert_valid_time_longer_than_825_days.go:
# Description: "Subscriber Certificates issued after 1 March 2018, but prior
# to 1 September 2020, MUST NOT have a Validity Period greater than 825
# days.", EffectiveDate: util.SubCert825Days, // 2018-03-02 Neither sets
# IneffectiveDate, so CheckEffective only ever tests the lower bound and
# both lints apply to every later certificate. lint.LintMetadata carries the
# field, 27 lints in lints/ set it, and the same family uses it:
# lint_e_server_cert_valid_time_longer_than_200_days.go bounds itself
# between the two SC081 milestones, and cabf_cs_br's 39-month lint between
# CABF_CS_BRs_1_2_Date and CABF_CS_CSC_31_Date. Both closing dates already
# exist as constants in util/time.go: the 39-month lint closes at
# util.SubCert825Days and the 825-day lint at util.AppleReducedLifetimeDate
# (2020-09-01), which is the effective date of the 398-day lint that
# replaced it. The two inputs are both zlint's own testdata and differ in
# notBefore. ./positive/ZT-013-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
N=e_sub_cert_valid_time_longer_than_39_months,e_sub_cert_valid_time_longer_than_825_days,e_tls_server_cert_valid_time_longer_than_398_days

for f in positive/ZT-013-issued-after-the-window.pem \
         negative/ZT-013-control-inside-the-window.pem ; do
  echo "== $f"
  echo "   $(openssl x509 -in "$D/$f" -noout -dates 2>/dev/null | tr '\n' ' ')"
  "$Z" -includeNames="$N" "$D/$f" || echo "   REFUSED"
  echo
done

cat <<'NOTE'

Observed (zlint v3.7.1-20-g1007b1d5):

SANIPv4Address.pem, notBefore 2021-09-01
e_sub_cert_valid_time_longer_than_39_months error
e_sub_cert_valid_time_longer_than_825_days error
e_tls_server_cert_valid_time_longer_than_398_days error

subCertValidTimeTooLong.pem, notBefore 2017-08-31
e_sub_cert_valid_time_longer_than_39_months error
e_sub_cert_valid_time_longer_than_825_days NE
e_tls_server_cert_valid_time_longer_than_398_days NE

Correct: NE for the 39-month and 825-day lints on the first certificate. The
control shows the mechanism working — CheckEffective already returns NE below
each lint's EffectiveDate, and the only thing missing is the bound above.

It was subject to the 398-day limit, which is reported correctly and on its
own would say everything a reader needs.

Reach, over the 21,778 corpus certificates zlint read:

  e_sub_cert_valid_time_longer_than_39_months   fires 133, of which 126 were
      issued on or after 2018-03-02 — 2018 (22), 2019 (6), 2021 (15),
      2022 (3), 2023 (70), 2024 (9), 2025 (1)
  e_sub_cert_valid_time_longer_than_825_days    fires 159, of which 113 were
      issued on or after 2020-09-01 — 2021 (16), 2022 (4), 2023 (71),
      2024 (9), 2025 (12), and one dated 2055

No conformance verdict changes: every certificate reported outside a window is
also reported by the stricter limit that replaced it. What changes is the
count and the reason. A consumer tallying distinct violated requirements sees
three where the document states one, and each superfluous finding cites a
clause that had been superseded before the certificate was signed.

Fix: IneffectiveDate: util.SubCert825Days on the 39-month lint, and
IneffectiveDate: util.AppleReducedLifetimeDate on the 825-day lint. NOTE
