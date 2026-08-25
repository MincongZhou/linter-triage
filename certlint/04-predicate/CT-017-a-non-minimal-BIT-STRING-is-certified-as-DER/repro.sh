#!/bin/bash
# CT-017 — certlint does not detect a non-minimal named-bit-list BIT STRING,
# although it reports "is not encoded using DER" for other DER violations.
# The certificate here encodes keyUsage as 03 03 07 06 00: two content
# octets, the second entirely padding, seven unused bits declared. X.690
# 11.2.2 requires trailing zero bits to be removed from a named bit list, so
# DER is 03 02 01 06. ./positive/CT-017-repro.sh /path/to/certlint-checkout
set -u
CD="${1:-/path/to/certlint}"
D="$(cd "$(dirname "$0")" && pwd)"
P="$D/positive/CT-017-non-minimal-keyusage-bitstring.pem"

echo "== the keyUsage extension as encoded (OID 2.5.29.15 = 06 03 55 1d 0f):"
openssl x509 -in "$P" -outform DER \
  | od -An -tx1 -v | tr -d ' \n' \
  | grep -o "0603551d0f[0-9a-f]\{0,24\}" | head -1
echo "   0603551d0f  0101ff  0405  0303070600"
echo "   OID         crit    OCTET STRING(5), then BIT STRING 03 03 07 06 00"

echo
echo "== cablint (PEM, CABF requirements):"
( cd "$CD" && ruby -I lib -I ext bin/cablint "$P" ) || echo FAILED
echo
echo "== certlint (DER, RFC 5280 + the compiled ASN.1 grammar):"
openssl x509 -in "$P" -outform DER -out /tmp/cl002.der
( cd "$CD" && ruby -I lib -I ext bin/certlint /tmp/cl002.der ) || echo FAILED
echo "   (empty output above = certlint had nothing to say)"

echo
echo "== the mechanism, isolated: certlint's DER test is a round trip"
( cd "$CD" && ruby -I lib -I ext -e '
require "certlint"
[["non-minimal 03 03 07 06 00", "\x03\x03\x07\x06\x00"],
 ["canonical   03 02 01 06",    "\x03\x02\x01\x06"]].each do |label, der|
  v = CertLint::ASN1Validator.new(der.dup.force_encoding("BINARY"), :KeyUsage)
  msgs = CertLint.check_pdu(:KeyUsage, der.dup)
  puts "#{label}"
  puts "   input      #{der.unpack1("H*")}"
  puts "   to_der     #{v.to_der.unpack1("H*")}    <- compared against input"
  puts "   messages   #{msgs.empty? ? "(none)" : msgs.inspect}"
end
' ) || echo FAILED

cat <<'NOTE'

certlint/lib/certlint/certlint.rb check_pdu():

der = validator.to_der unless der == content
      messages << "E: #{pdu} is not encoded using DER"
    end

The asn1c-generated encoder reproduces the input's unused-bit count and
content octets verbatim rather than canonicalising them, so a non-minimal
named-bit-list BIT STRING is a fixed point of the round trip and the DER test
passes it. A DER re-encoder that applied X.690 11.2.2 would emit 03 02 01 06
for this input, the comparison would fail, and certlint would already report
"E: KeyUsage is not encoded using DER".

For comparison, on the same certificate: zlint e_incorrect_ku_encoding,
e_superfluous_ku_encoding x509lint E: Bit string with leading 0
  pkilint    itu.invalid_asn1_syntax (FATAL): Trailing zero bit in named BIT STRING
  certlint   nothing, from either command

Control that the silence is a result and not a failure to read: certlint
reports twelve findings on zlint's uniqueIdVersion1.pem, including
"E: Certificate is not encoded using DER".
NOTE
