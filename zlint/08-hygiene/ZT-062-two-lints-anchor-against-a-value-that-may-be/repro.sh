#!/bin/bash
# ZT-062 — two lints anchor a `+` regex against a value that may be empty,
# so an empty subject attribute is reported as holding something it does not
# hold. lints/rfc/lint_subject_printable_string_badalpha.go:
# printableStringRegex = regexp.MustCompile(`^[a-zA-Z0-9\=\(\)\+,\-.\/:\?
# ']+$`) ... return errors.New("encoded PrintableString contained illegal
# characters") lints/community/lint_subj_country_not_uppercase.go: var re =
# regexp.MustCompile("^[A-Z]+$") ... Details: "Country codes must be
# comprised of uppercase A-Z letters", Both quantifiers are `+`, so neither
# pattern matches the empty string, and both lints treat "did not match" as
# "holds a prohibited character". Executed rather than read: "" match=false
# "US" match=true "a_b" match=false " " match=true An empty PrintableString
# contains no illegal character; an empty countryName is not a lower-case
# country code. Both messages assert a fact about a value that has no
# characters to assert it of, and both defects are already reported
# correctly and separately -- by e_ca_country_name_missing,
# e_ca_country_name_invalid and e_subject_country_not_iso on the same
# certificate. The case file is zlint's own testdata for the empty-country
# lints. The control carries a real illegal character and a real country
# code. ./positive/ZT-062-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
N=e_subject_printable_string_badalpha,e_subj_country_not_uppercase,e_ca_country_name_missing,e_ca_country_name_invalid,e_subject_country_not_iso

for f in positive/ZT-062-empty-country-and-printablestring.pem \
         negative/ZT-062-control-real-illegal-character.pem ; do
  echo "== $f"
  openssl x509 -in "$D/$f" -noout -subject -nameopt sep_comma_plus 2>/dev/null \
    | sed 's/^/   /'
  "$Z" -includeNames="$N" "$D/$f" || echo "   REFUSED"
  echo
done

cat <<'NOTE'

Observed (zlint v3.7.1-20-g1007b1d5):

caBlankCountry.pem, countryName present and empty
e_subject_printable_string_badalpha error
          "RawSubject attr oid 2.5.4.6 encoded PrintableString contained
           illegal characters"
      e_subj_country_not_uppercase         error
          "Country codes must be comprised of uppercase A-Z letters"
      e_ca_country_name_missing            error   (correct)
      e_ca_country_name_invalid            error   (correct)
      e_subject_country_not_iso            error   (correct)

  subjectCommonNamePrintableStringBadAlpha.pem
      e_subject_printable_string_badalpha  error   (correct)

Correct: pass from the first two lints on the empty value. Three other lints
already state the defect, and each states it accurately.

Reach, over the 21,778 corpus certificates zlint read:

e_subject_printable_string_badalpha fires 25, of which 8 carry an empty
PrintableString and no character outside the repertoire -- 7 of zlint's own
fixtures and Mozilla CA incident bug 1391074, whose organizationalUnitName is
present and empty e_subj_country_not_uppercase fires 145, of which 6 carry an
empty countryName -- all zlint's own fixtures

No conformance verdict changes; every certificate is non-conformant for the
reason the other three lints give. What changes is the reason and the count. A
consumer tallying distinct violated requirements sees five where the document
states one, and two of the five name a character that is not there.

Fix: `*` in place of `+` in both patterns, with an explicit emptiness test
where emptiness is the finding -- or, for the country lint, guard on
`len(cc) > 0` and leave the empty case to the three lints that own it.
NOTE
