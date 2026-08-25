#!/bin/bash
# ZT-043 -- e_utf8_latin1_mixup reads only the first value of each subject
# field, so a clean first value hides a damaged second one.
# lints/community/lint_utf8_latin1_mixup.go names twelve fields of
# x509.Certificate.Subject, each of which is a []string, and reads index 0:
# strSlice := field.Interface().([]string) if len(strSlice) > 0 { if
# containsUtf8Latin1Mixup(strSlice[0]) { A distinguished name may carry an
# attribute more than once, and organizationalUnitName routinely does.
# Certificate: a real production certificate from Mozilla bug 1431164, whose
# subject carries two organizationalUnitName attributes -- OU[0] = "sede
# electronica" (correctly encoded) OU[1] = "... DE LA TORRE D<mojibake>EN
# BESORA" (UTF-8 read as Latin-1) Control: a real production certificate
# from Mozilla bug 1715024, whose subject also carries two, with the damage
# in the first -- OU[0] = "Sistemas de Informaci<mojibake>n" OU[1] =
# "PremiumSSL Legacy Wildcard" The two differ in which index the damage sits
# in and in nothing else that matters, which is what makes the pair evidence
# rather than one output.
set -u
Z=${ZLINT:-$HOME/.local/bin/zlint}
D=$(dirname "$0")
L=e_utf8_latin1_mixup
echo "zlint: $($Z -version 2>&1 | head -1)"
echo

for f in "$D/positive/ZT-043-damage-in-second-ou.pem" \
         "$D/negative/ZT-043-control-damage-in-first-ou.pem"; do
    echo "--- $(basename "$f")"
    openssl x509 -in "$f" -noout -subject 2>/dev/null \
        | tr ',' '\n' | grep -i 'OU *=' | sed 's/^ */    OU: /'
    $Z -includeNames=$L "$f" 2>/dev/null | tr ',' '\n' | sed 's/^/    /'
    echo
done

echo "observed: pass where the damage is in the second organizationalUnitName,"
echo "          error where it is in the first."
echo "correct : error on both. Nothing about a distinguished name makes the"
echo "          first occurrence of an attribute the only one worth reading."
echo "fix     : iterate the slice --"
echo "              for _, s := range strSlice {"
echo "                  if containsUtf8Latin1Mixup(s) { ... }"
echo "              }"
echo "          and the same in lint_subj_contains_html_entities.go, which has"
echo "          the identical shape."
echo
echo "Reach on this corpus is 1 of 21,778, and it is a real certificate rather"
echo "than a fixture. The population is any subject carrying an attribute more"
echo "than once, which is common for organizationalUnitName."
