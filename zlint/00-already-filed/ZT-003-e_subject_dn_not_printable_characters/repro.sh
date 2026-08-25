#!/bin/bash
# ZT-003 — e_subject_dn_not_printable_characters reads every subject
# attribute as UTF-8, so the zero octets of a BMPString or UniversalString
# read as U+0000. lints/rfc/lint_subject_dn_not_printable_characters.go:
# bytes := attrTypeAndValue.Value.Bytes for len(bytes) > 0 { r, size :=
# utf8.DecodeRune(bytes) if r < 0x20 { return &lint.LintResult{Status:
# lint.Error} } ... `Value.Bytes` is the content octets of the attribute
# value, whatever string type carried it. BMPString encodes every code point
# in two octets and UniversalString in four, so any character below U+0100
# -- which is every ASCII letter -- is written with a leading 0x00.
# utf8.DecodeRune reads that octet as U+0000 and the lint reports a control
# character. Executed rather than read, over the content octets of "US" as a
# BMPString: 00 55 00 53 rune=U+0000 size=1 -> lint sees control: true
# rune=U+0055 size=1 -> lint sees control: false rune=U+0000 size=1 -> lint
# sees control: true rune=U+0053 size=1 -> lint sees control: false The two
# case files are zlint's own testdata for a different lint,
# e_subject_rdns_correct_encoding, whose whole purpose is to carry an
# attribute in a string type the BR table does not permit. Their subject
# values are the ASCII strings "BMPString" and "U", holding no control
# character at all. The control file is this lint's own positive fixture,
# whose organizationName is a UTF8String holding c3 a2 c2 80 c2 93 -- U+00E2
# U+0080 U+0093, an en-dash whose UTF-8 octets were encoded a second time --
# so U+0080 and U+0093, both C1 controls, really are in the value.
# ./positive/ZT-003-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
N=e_subject_dn_not_printable_characters,e_subject_rdns_correct_encoding

for f in positive/ZT-003-subject-givenname-bmpstring.pem \
         positive/ZT-003-subject-commonname-universalstring.pem \
         negative/ZT-003-control-real-control-character.pem ; do
  echo "== $f"
  openssl x509 -in "$D/$f" -noout -subject -nameopt sep_comma_plus,show_type,esc_ctrl \
    2>/dev/null | sed 's/^/   /'
  "$Z" -includeNames="$N" "$D/$f" || echo "   REFUSED"
  echo
done

cat <<'NOTE'

Observed (zlint v3.7.1-20-g1007b1d5):

  subjectGivenNameWrongEncoding.pem, givenName = BMPString "BMPString"
      e_subject_dn_not_printable_characters   error
      e_subject_rdns_correct_encoding         error   (correct)

  subjectCNWrongEncoding.pem, commonName = UniversalString "U"
      e_subject_dn_not_printable_characters   error
      e_subject_rdns_correct_encoding         error   (correct)

  subjectDNNotPrintableCharacters.pem, a UTF8String holding U+0080 and U+0093
      e_subject_dn_not_printable_characters   error   (correct)

Correct: pass on the first two. Neither subject contains a character below
U+0020 or in U+007F..U+009F. What they contain is a string type the BR
encoding table forbids, which the sibling lint reports and is the finding a CA
would act on.

UniversalString subject attribute; all thirteen have a 0x00 in the content
octets, all thirteen are faulted, and none of them holds a control character.
The other 12 firings are narrow-string attributes that really do -- eleven
subscriber certificates from CA incident bugs and one trust-store root. So 13
of 25 firings, 52 percent, are this defect. Eight of the thirteen are zlint's
own testdata.

Fix: decode by tag before scanning. util.ParseBMPString already exists for the
two-octet case and the lint file next door,
lint_ext_cert_policy_explicit_text_too_long.go, calls it for exactly this
reason. UniversalString needs a four-octet equivalent. NOTE
