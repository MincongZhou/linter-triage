#!/bin/bash
# CT-024 — "E: Unallowed key usage for <alg> public key (...)" names a key
# usage that does not exist whenever OpenSSL cannot name the bits. bash
# positive/CT-024-repro.sh [/path/to/certlint] Needs ruby and certlint's
# ext/ built.
set -u
CD="${1:-/path/to/certlint}"
HERE="$(cd "$(dirname "$0")" && pwd)"
echo "certlint: $CD"; echo

echo "== the control: a real unallowed bit =="
openssl x509 -in "$HERE/negative/CT-024-control-real-unallowed-bit.der" -inform der -noout -text \
    | grep -A1 'X509v3 Key Usage' | sed 's/^/   /'
( cd "$CD" && ruby -I lib -I ext bin/certlint "$HERE/negative/CT-024-control-real-unallowed-bit.der" 2>&1 ) \
    | grep 'Unallowed key usage' | sed 's/^/   /'
echo "   ^ names the offending usage. This is the message working."
echo

echo "== case 1: a keyUsage BIT STRING with every bit clear =="
openssl x509 -in "$HERE/positive/CT-024-keyusage-no-bits.der" -inform der -noout -text \
    | grep -A1 'X509v3 Key Usage' | sed 's/^/   /'
( cd "$CD" && ruby -I lib -I ext bin/certlint "$HERE/positive/CT-024-keyusage-no-bits.der" 2>&1 ) \
    | grep 'Unallowed key usage' | sed 's/^/   /'
echo "   ^ '....' is not a key usage. The defect is that NO bit is set."
echo

echo "== case 2: a keyUsage extnValue that is not a BIT STRING at all =="
openssl x509 -in "$HERE/positive/CT-024-keyusage-undecodable.der" -inform der -noout -text \
    | grep -A1 'X509v3 Key Usage' | sed 's/^/   /'
( cd "$CD" && ruby -I lib -I ext bin/certlint "$HERE/positive/CT-024-keyusage-undecodable.der" 2>&1 ) \
    | grep 'Unallowed key usage' | sed 's/^/   /'
echo "   ^ '.' is not a key usage either. The extension does not decode:"
python3 -c "
from cryptography import x509 try:
    x509.load_der_x509_certificate(open('$HERE/positive/CT-024-keyusage-undecodable.der','rb').read()).extensions
    print('     cryptography: parsed')
except Exception as e:
    print('     cryptography refuses the extension list:', e)
" 2>/dev/null || echo "     (python cryptography not available)"
echo

echo "== executed, not read: what OpenSSL renders for each shape =="
( cd "$CD" && ruby -ropenssl -e '
# 03 02 07 80 = BIT STRING, 7 unused bits, digitalSignature 03 02 07 00 =
# BIT STRING, 7 unused bits, nothing set 04 01 00 = an OCTET STRING where a
# BIT STRING belongs. The rendering is the raw bytes, one dot per
# unprintable one, so the exact number of dots follows the length and not
# the shape.
{"digitalSignature" => "\x03\x02\x07\x80",
 "all bits clear"   => "\x03\x02\x07\x00",
 "not a BIT STRING" => "\x04\x01\x00"}.each do |label, der|
  v = OpenSSL::X509::Extension.new("2.5.29.15", der, true).value rescue "<raised>"
  puts format("   %-18s .value => %p", label, v)
end' )
echo "   ^ keyusage.rb:29 splits THAT string on commas and allow-lists the parts."
echo

cat <<'EOF'
==============================================================
observed  E: Unallowed key usage for RSA public key (....) E: Unallowed key
          usage for RSA public key (.)

correct   Neither certificate asserts a key usage outside the RSA set. The
          first asserts none at all; the second carries a keyUsage extnValue
that is not a BIT STRING. Two different defects, neither of them this
message's.

mechanism lib/certlint/extensions/keyusage.rb:29

              v = OpenSSL::X509::Extension.new('2.5.29.15', content, critical)
                    .value.split(',').map(&:strip)

The check reads the RENDERED extension rather than the decoded bits. OpenSSL
prints a dot for each bit position it has no name for, so both malformed
shapes arrive as strings of dots, and the allow-list test at line 49 —

              if v.any? { |u| !allowed.include? u }

— is true for them. The same line reached from the DSA, EC and DH branches has
the same property.

severity Low. The certificate is defective in every one of these cases and
certlint condemns it, so no verdict is wrong — but the message names a key
usage that does not exist, which no CA can act on.

fix Decide the two shapes before the allow-list, from the decoded extension
rather than from its rendering:

              asn1 = OpenSSL::ASN1.decode(content) rescue nil
              if asn1.nil? || !asn1.is_a?(OpenSSL::ASN1::BitString)
                messages << 'E: keyUsage is not a valid BIT STRING'
return messages end
              if v.empty? || v.all? { |u| u =~ /\A\.+\z/ }
                messages << 'E: keyUsage asserts no bits'
return messages end

The second test is the one that matters even without the first: a rendering
that is dots and nothing else is never a key usage.
EOF
