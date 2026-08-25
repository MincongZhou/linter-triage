#!/bin/bash
# ZT-017 — e_qcstatem_qctype_oneonly is dated by a constant naming a
# different document, and misses the clause by five and a half years.
# Citation: "ETSI EN 319 412 - 5 V2.5.0 (2025 - 03) / Section 4.2.3"
# EffectiveDate: util.EtsiEn319_411_2_V2_5_0_Date
# EtsiEn319_411_2_V2_5_0_Date = 2023-07-01 The citation names EN 319 412-5;
# the constant is named for EN 319 411-2, a different document, and carries
# 2023-07-01. Neither is the clause's own date: § 4.2.3's "one and only one"
# is in EN 319 412-5 v2.2.1, effective 2017-11-01, which is the date zlint's
# own two sibling QcType lints use -- e_qcstatem_qctype_web and
# e_qcstatem_qctype_smime both take util.EtsiEn319_412_5_V2_2_1_Date. Three
# lints, one clause, two dates.
set -u
Z=${ZLINT:-$HOME/.local/bin/zlint}
D=$(dirname "$0")
echo "zlint: $($Z -version 2>&1 | head -1)"
echo

for c in positive/ZT-017-three-qctypes-2019 negative/ZT-017-control-two-qctypes-2025; do
  f="$D/$c.pem"
  printf '%-24s ' "$(openssl x509 -in "$f" -noout -startdate | cut -d= -f2)"
  $Z -includeNames=e_qcstatem_qctype_oneonly "$f" 2>/dev/null
  python3 - "$f" <<'PY'
import sys, warnings
warnings.filterwarnings("ignore")
from cryptography import x509
c = x509.load_pem_x509_certificate(open(sys.argv[1], "rb").read())
for e in c.extensions:
    if e.oid.dotted_string == "1.3.6.1.5.5.7.1.3":
        raw = e.value.public_bytes().hex()
        n = raw.count("04008e46010603") + raw.count("04008e46010601") \
            + raw.count("04008e46010602")
        print(f"    the QcType statement names {n} purposes")
PY
done

echo
echo "observed: NE on the 2019 certificate, which names all three purposes"
echo "correct : error — EN 319 412-5 § 4.2.3 has said 'one and only one' since"
echo "          v2.2.1, 2017-11-01"
echo "fix     : use util.EtsiEn319_412_5_V2_2_1_Date, as the two sibling QcType"
echo "          lints already do, and correct the Citation to the version that"
echo "          states the clause rather than the newest one that repeats it."
echo
echo "reach   : 3 of 21,778 — QcStmtValidLimitValue.pem,"
echo "          QcStmtInvalidLimitValue.pem and QcStmtEtsiTwoQcTypesCert15.pem,"
echo "          all zlint's own fixtures, issued 2018 and 2019, each naming"
echo "          more than one purpose and each returning NE."
