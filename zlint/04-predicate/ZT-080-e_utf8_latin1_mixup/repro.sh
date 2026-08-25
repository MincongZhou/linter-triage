#!/bin/bash
# ZT-080 - e_utf8_latin1_mixup omits two manglings whose second character is
# invisible, and one of them is `à`, which is common in Italian, French,
# Portuguese, Catalan and Occitan. lints/community/lint_utf8_latin1_mixup.go
# builds a table of miscoded diacritics rather than a rule: // This table
# does not cover 100% of all possible miscodings, but it // avoids false
# positives. miscodedDiacritics := []string{ "Ã€", // À "Ã‚", // Â ... 57
# entries, all beginning U+00C3. A Latin-1 letter U+00E0..U+00FF encodes in
# UTF-8 as C3 xx, and reading those two bytes as Windows-1252 gives U+00C3
# followed by whatever cp1252 maps xx to. Enumerating all 64 shows the table
# omits seven, and the omissions are not arbitrary: à -> U+00C3 U+00A0
# NO-BREAK SPACE í -> U+00C3 U+00AD SOFT HYPHEN Á Í Ï Ð Ý second byte
# undefined in cp1252 The first two are the point. Both second characters
# are **invisible** -- a no-break space and a soft hyphen render as nothing
# or as an ordinary space -- so a table assembled by pasting samples of real
# mojibake loses them in the paste and nobody sees the loss. The other five
# are bytes cp1252 does not define, which a UTF-8 source file cannot hold as
# a literal at all. zlint's comment concedes the table is not exhaustive, so
# this is not a contradiction of the lint's own claim. It is filed because
# the *mechanism* is specific and the fix is two lines: the omissions are
# systematic rather than a sampling accident, and one of them is a common
# letter. ./positive/ZT-080-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
LINT=e_utf8_latin1_mixup

echo "== two certificates from the same CA incident, Mozilla bug 1724458"
echo "   Sectigo, 2021-08-06, 'certificates containing Mojibake in place of"
echo "   UTF-8 encoded Extended ASCII characters'"
echo

for pair in "positive/ZT-080-a-grave-mangled.der:organizationName holds 'AutoritÃ\xa0' -- à mangled, U+00C3 U+00A0:MISSED" \
            "negative/ZT-080-e-grave-control.der:localityName holds 'VallÃ¨s' -- è mangled, U+00C3 U+00A8:in the table"; do
  f="${pair%%:*}"; rest="${pair#*:}"; what="${rest%%:*}"; expect="${rest##*:}"
  printf "   %-32s %s\n" "$(basename "$f")" "$what"
  r=$("$Z" -includeNames "$LINT" -format der "$D/$f" 2>/dev/null \
      | python3 -c 'import sys,json; print(json.load(sys.stdin)["'"$LINT"'"]["result"])')
  printf "   %-32s zlint says: %-8s (%s)\n\n" "" "$r" "$expect"
done

echo "   observed  the à certificate passes; the è certificate is reported."
echo "   correct   both are the same defect and both should be reported."
echo
echo "== the omission, derived rather than asserted"
python3 - "/path/to/zlint/v3/lints/community/lint_utf8_latin1_mixup.go" <<'PY'
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
tbl = set(re.findall(r'"(Ã[^"]*)"', src))
missing = []
for cp in range(0xC0, 0x100):
    ch = chr(cp)
    try:
        mang = ch.encode("utf-8").decode("cp1252")
    except UnicodeDecodeError:
        missing.append((ch, "second byte undefined in cp1252")); continue
    if mang not in tbl:
        missing.append((ch, " ".join(f"U+{ord(c):04X}" for c in mang)))
print(f"      {len(tbl)} entries; {len(missing)} of the 64 manglings absent:")
for ch, m in missing:
    print(f"        {ch}  ->  {m}")
PY
echo
echo "== fix"
echo "   add two entries, written as escapes so the invisible characters"
echo "   survive review:"
echo "      \"\\u00c3\\u00a0\", // à"
echo "      \"\\u00c3\\u00ad\", // í"
echo "   The remaining five need the table to hold bytes cp1252 leaves"
echo "   undefined, which is a different change and may not be worth making."
