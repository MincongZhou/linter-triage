#!/bin/bash
# ZT-040 — e_key_usage_incorrect_length measures the position of the highest set bit, not the number of bits the BIT STRING declares. A keyUsage that asserts only an undefined bit passes; one that asserts nine defined bits with a padded length fails.  lints/rfc/lint_key_usage_incorrect_length.go:  Description: "The key usage is a bit string with exactly nine possible flags", Citation:    "RFC 5280: 4.2.1.3",  unused := kuBytes[2] kuBig := big.NewInt(0).SetBytes(keyUsageVal.Bytes) if !kuBig.IsInt64() || kuBig.Int64()>>unused >= 512 { return &lint.LintResult{Status: lint.Error, ...}  `kuBig >> unused` right-aligns the value and `>= 512` asks whether it needs ten or more bits to write down. That is the position of the highest *set* bit, which is not the declared bit length. Both directions follow. Executed against the function copied verbatim:  03 02 07 80     digitalSignature, minimal                 -> pass 03 03 07 08 80  keyAgreement+decipherOnly, minimal        -> pass 03 03 00 08 80  keyAgreement+decipherOnly, unused=0       -> error 03 03 06 00 40  ONLY undefined bit 9 asserted             -> pass 03 03 00 00 01  ONLY undefined bit 15 asserted            -> pass 03 03 06 80 40  digitalSignature + undefined bit 9        -> error  The false negative is the serious half: a certificate asserting a keyUsage bit RFC 5280 does not define escapes the lint whenever every defined bit is clear, so whether the check runs to a verdict is under the control of the certificate. The false positive is the third line -- a keyUsage whose bits are all defined but whose BIT STRING was not minimally encoded, which e_incorrect_ku_encoding already reports, precisely and by name. The pair below differs in one bit. Both declare ten bits and both assert undefined bit 9; the control also asserts digitalSignature, which is what lifts the right-aligned value past the threshold and makes the lint see the undefined bit it missed on the case file.  ./positive/ZT-040-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
N=e_key_usage_incorrect_length,e_incorrect_ku_encoding,e_superfluous_ku_encoding

for f in positive/ZT-040-keyusage-undefined-bit-9-only.pem \
         negative/ZT-040-control-keyusage-undefined-bit-9-and-digitalsignature.pem \
         positive/ZT-040-keyusage-nonminimal-but-in-range.pem ; do
  echo "== $f"
  openssl x509 -in "$D/$f" -noout -text 2>/dev/null \
    | grep -A2 -i "key usage" | head -3 | sed 's/^/   /'
  python3 - "$D/$f" <<'PY'
import base64, sys
d = open(sys.argv[1], "rb").read()
b = d.split(b"-----BEGIN CERTIFICATE-----", 1)[1].split(b"-----END", 1)[0]
raw = base64.b64decode(b"".join(b.split()))
i = raw.find(bytes([0x06, 0x03, 0x55, 0x1D, 0x0F]))       # OID 2.5.29.15
j = raw.find(bytes([0x03]), raw.find(bytes([0x04]), i))    # the BIT STRING
print("   keyUsage extnValue:", raw[j:j + 2 + raw[j + 1]].hex())
PY
  "$Z" -includeNames="$N" "$D/$f" || echo "   REFUSED"
  echo
done

cat <<'NOTE'

Observed (zlint v3.7.1-20-g1007b1d5):

keyUsage 03 03 06 00 40 -- ten declared bits, only undefined bit 9 asserted
e_key_usage_incorrect_length pass e_incorrect_ku_encoding pass
e_superfluous_ku_encoding pass

keyUsage 03 03 06 80 40 -- the same, plus digitalSignature
e_key_usage_incorrect_length error

keyUsage 03 03 00 08 80 -- keyAgreement + decipherOnly, unused declared 0
e_key_usage_incorrect_length error
          "the key usage ([8 128]) contains a value that is out of bounds of
           the range of possible KU values."
      e_incorrect_ku_encoding        error   (correct)
          "the number of 'unused bits' is declared to be 0, but it should be 7"

Correct: error on the first, error on the second, pass on the third from this
lint. 0x08 is keyAgreement and 0x80 in the second octet is decipherOnly; both
are defined, so nothing about that value is out of bounds. What is wrong with
it is the encoding, and the lint that says so gets it exactly right.

Three are the false-positive shape -- zlint's own
ec_multipurpose_key_agreement_decipher_only.pem,
ec_multipurpose_valid_ku_august_2023.pem and
ec_legacy_digital_signature_key_agreement_content_commitment_decipher_only_ku.pem,
each a decipherOnly keyUsage written with unused=0 -- and
e_incorrect_ku_encoding reports every one of them correctly.

Provenance: the first two files are fabricated. Built by python cryptography
43.0.0 as an ordinary serverAuth subscriber certificate -- notBefore
2024-06-01, CA:FALSE, one dNSName SAN, same key and same fields in both --
with keyUsage written through x509.UnrecognizedExtension, since the library's
KeyUsage type cannot express a bit past decipherOnly, which is the point. The
third is zlint's own testdata.

Fix: test the declared length rather than the value. The used bit count is
`len(keyUsageVal.Bytes)*8 - int(unused)`; error when a bit at position 9 or
beyond is set within it. That reports the case file, keeps the control, and
leaves the non-minimal encoding to e_incorrect_ku_encoding. NOTE
