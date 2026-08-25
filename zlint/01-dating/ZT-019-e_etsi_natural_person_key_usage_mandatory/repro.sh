#!/bin/bash
# ZT-019 — e_etsi_natural_person_key_usage_mandatory is dated four years and
# five months after the clause it enforces. Citation: "ETSI EN 319 412-2
# V2.2.1 (2020-07) / Section 4.3.2" EffectiveDate:
# util.EtsiEn319_412_2_V2_2_1_Date // 2020-07-01 EN 319 412-2 v2.1.1,
# February 2016 -- the first edition of the document -- carries clause 4.3.2
# in the same words: The key usage extension shall be present and shall
# contain one (and only one) of the key usage settings defined in table 1
# (A, B, C, D, E or F). v2.4.1 differs by one comma and by the requirement
# number NAT-4.3.2-1, which the series gained when it took EN 319 411-1's
# numbering scheme. Verified against the complete series, filed in
# Specs/etsi/: v2.1.1, v2.2.1, v2.3.1 and v2.4.1 all carry the sentence. WHY
# THIS ONE IS EASY TO GET WRONG, AND WORTH SAYING PLAINLY. The document's
# change history does record a change request against this clause between
# the two editions -- "on key usage in ESI(18)63_039r1", implemented in
# v2.1.2 of February 2020. So a version search for the current wording finds
# real evidence of change. The change is to the wording around the
# requirement, not to the requirement, and no search can tell those apart.
# Reading the older edition can. Certificates: fabricated, differing only in
# notBefore, same key, built by ZT-019-build.py beside this file.
set -u
Z=${ZLINT:-$HOME/.local/bin/zlint}
D=$(dirname "$0")
L=e_etsi_natural_person_key_usage_mandatory
echo "zlint: $($Z -version 2>&1 | head -1)"
echo

for c in positive/ZT-019-qcp-n-no-keyusage-2018 negative/ZT-019-control-2020-08-01; do
  f="$D/$c.pem"
  printf '%-14s %s\n' \
    "$(openssl x509 -in "$f" -noout -startdate | cut -d= -f2 | awk '{print $1, $2, $4}')" \
    "$($Z -includeNames=$L "$f" 2>/dev/null)"
done

echo
echo "    both certificates assert QCP-n (0.4.0.194112.1.0) and carry no keyUsage:"
for c in positive/ZT-019-qcp-n-no-keyusage-2018 negative/ZT-019-control-2020-08-01; do
  printf '    %-38s policies %s  keyUsage %s\n' "$c" \
    "$(openssl x509 -in "$D/$c.pem" -noout -text | grep -A1 'Certificate Policies' | tail -1 | tr -d ' ')" \
    "$(openssl x509 -in "$D/$c.pem" -noout -text | grep -c 'X509v3 Key Usage')"
done

echo
echo "observed: NE on the 2018 certificate, error on the 2020 one"
echo "correct : error on both — EN 319 412-2 has required the extension since"
echo "          v2.1.1, February 2016, the document's first edition"
echo "fix     : date the lint to v2.1.1 rather than to the edition in which the"
echo "          requirement was read. The sibling lints on the same sentence,"
echo "          e_etsi_natural_person_key_usage_correct_values and"
echo "          w_etsi_natural_person_key_usage_preferred_values, carry the same date"
echo "          and the same clause, so the fix is one constant for three."
