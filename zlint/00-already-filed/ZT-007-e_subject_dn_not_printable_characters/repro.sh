#!/bin/bash
# ZT-007 — e_subject_dn_not_printable_characters scans raw DER content
# octets regardless of the attribute's declared ASN.1 tag, so the padding
# octets of a BMPString or UniversalString read as U+0000 control
# characters. lints/rfc/lint_subject_dn_not_printable_characters.go decodes
# attrTypeAndValue.Value.Bytes with utf8.DecodeRune and faults any rune <
# 0x20. Those Bytes are the undecoded content octets. A UniversalString
# encodes each character as four octets UCS-4BE and a BMPString as two
# UCS-2BE, so every ASCII character carries three or one leading 0x00 --
# which that scan reads as NUL, a C0 control character that the decoded
# value does not contain. The sibling DN-encoding lints
# (e_subject_dn_country_not_printable_string and the issuer/serialNumber
# equivalents) test the declared TAG instead, which is a differently shaped
# and correct question -- so this is not a house pattern. Case : zlint's own
# fixture. commonName is a UniversalString, content 00 00 00 55, decoding to
# the single character "U". Control: a real trust-store root whose
# organizationName is a BMPString of ordinary German text. Same mechanism,
# real issuance.
set -u
Z=${ZLINT:-$HOME/.local/bin/zlint}
D=$(dirname "$0")
L=e_subject_dn_not_printable_characters
echo "zlint: $($Z -version 2>&1 | head -1)"

for pair in "positive/ZT-007-universalstring-cn-u.pem:PEM" "positive/ZT-007-bmpstring-real-root.der:DER"; do
  f=${pair%%:*}; form=${pair##*:}
  echo
  echo "-- $f --"
  $Z -includeNames=$L "$D/$f" 2>/dev/null
  openssl x509 -in "$D/$f" -inform $form -noout -subject 2>/dev/null | sed 's/^/  /'
  python3 - "$D/$f" "$form" <<'PY'
import sys, warnings
warnings.filterwarnings("ignore")
from cryptography import x509
b = open(sys.argv[1], "rb").read()
c = x509.load_pem_x509_certificate(b) if sys.argv[2] == "PEM" else x509.load_der_x509_certificate(b)
ctrl = [(a.oid._name, a.value) for a in c.subject
        if any(ord(ch) < 0x20 for ch in str(a.value))]
print(f"  attributes whose DECODED value holds a control character: {ctrl}")
PY
done

echo
echo "observed: error   (control characters reported)"
echo "correct : pass    (no decoded value contains one)"
echo "fix     : decode the value per its declared tag before scanning for C0"
