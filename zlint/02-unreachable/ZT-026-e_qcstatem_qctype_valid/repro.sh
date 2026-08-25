#!/bin/bash
# ZT-026 - e_qcstatem_qctype_valid's error path is never exercised, and the
# test that would have caught it asserts nothing. The lint is effective in
# [2017-11-01, 2023-07-01) -- EtsiEn319_412_5_V2_2_1 to
# EtsiEn319_411_2_V2_5_0. TestEtsiQcType declares ExpectedResult for seven
# cases, including `lint.Error` for qctWithWrongType_2024.pem, and then
# compares only result.Details. Every case leaves ExpectedDetails at "", and
# the lint returns empty Details for pass/NA/NE, so the function passes
# whatever the statuses are -- which is why a fixture dated ten months past
# the window was never noticed. It is a slip and not a convention: of 730
# test functions that declare a lint.LintStatus and call test.TestLint, this
# is the only one that never compares a Status. The check is in this script
# if a source tree is given. ./positive/ZT-026-repro.sh /path/to/zlint
# [/path/to/zlint/source/v3]
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
SRC="${2:-}"
L=e_qcstatem_qctype_valid

echo "== the lint's effective window, from the source constants"
echo "   EffectiveDate   EtsiEn319_412_5_V2_2_1_Date = 2017-11-01"
echo "   IneffectiveDate EtsiEn319_411_2_V2_5_0_Date = 2023-07-01"

echo
echo "== the fixture the test declares lint.Error for"
openssl x509 -in "$D/positive/ZT-026-qct-wrong-type-2024.pem" -noout -startdate
"$Z" -includeNames "$L" "$D/positive/ZT-026-qct-wrong-type-2024.pem"

echo
echo "== control: a certificate inside the window, same lint, judged not gated"
openssl x509 -in "$D/negative/ZT-026-control-inside-window.pem" -noout -startdate
"$Z" -includeNames "$L" "$D/negative/ZT-026-control-inside-window.pem"

if [ -n "$SRC" ] && [ -d "$SRC/testdata" ]; then
  echo
  echo "== every result this lint produces over all of zlint's own testdata"
  for f in "$SRC"/testdata/*.pem; do
    "$Z" -includeNames "$L" "$f" 2>/dev/null
  done | grep -oE '"result":"[a-zA-Z]+"' | sort | uniq -c
  echo "   (no \"error\" line means the error branch is unreached)"

  echo
  echo "== test functions declaring a LintStatus that never compare one"
  grep -rl 'test.TestLint' "$SRC/lints" --include='*_test.go' | while read -r t; do
    # \b is not portable across awk implementations and the closing brace
    # line is not always bare -- both silently emptied this sweep once.
    awk -v F="$t" '
      /^func Test/ { fn=$2; sub(/\(.*/, "", fn); has=0; asserts=0 }
      { if ($0 ~ /lint\.(Pass|NA|NE|Error|Fatal|Warn|Notice|Info)[^a-zA-Z]/) has=1
        if ($0 ~ /\.Status/) asserts=1 }
      /^}/ { if (fn != "" && has && !asserts) print "  " F "  " fn; fn="" }
    ' "$t"
  done
fi

echo
echo "observed  qctWithWrongType_2024.pem answers NE; TestEtsiQcType passes"
echo "          anyway, because it compares result.Details and never"
echo "          result.Status. No fixture makes this lint return error."
echo "correct   assert result.Status against tc.ExpectedResult, then re-date"
echo "          the qct* fixtures inside the window (or expect NE for them)."
