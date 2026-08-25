#!/bin/bash
# CT-008 — "E: UTCTime without seconds" cannot fire for the defect it names,
# and every certificate it does fire on has seconds. bash
# positive/CT-008-repro.sh [/path/to/certlint] Needs ruby and certlint's
# ext/ built.
set -u
CD="${1:-/path/to/certlint}"
HERE="$(cd "$(dirname "$0")" && pwd)"
echo "certlint: $CD"; echo

echo "== what the check fires on: SecureNet CA Class B, a real 1999 root =="
openssl asn1parse -inform der -in "$HERE/positive/CT-008-utctime-with-seconds-wrong-zone.der" \
    | grep UTCTIME | sed 's/^/   /'
echo "   ^ twelve digits each: YYMMDDHHMMSS. The seconds are PRESENT."
( cd "$CD" && ruby -I lib -I ext bin/certlint "$HERE/positive/CT-008-utctime-with-seconds-wrong-zone.der" 2>&1 ) \
    | grep -i 'time' | sed 's/^/   /'
echo

echo "== the control: a UTCTime that genuinely has no seconds =="
openssl asn1parse -inform der -in "$HERE/negative/CT-008-control-utctime-truly-no-seconds.der" \
    | grep UTCTIME | sed 's/^/   /'
echo "   ^ ten digits: YYMMDDHHMM. This is the defect the message names."
( cd "$CD" && ruby -I lib -I ext bin/certlint "$HERE/negative/CT-008-control-utctime-truly-no-seconds.der" 2>&1 ) \
    | sed 's/^/   /'
echo "   ^ the message does not appear. certlint bails before reaching it."
echo

echo "== executed, not read: what Ruby's decoder does with each form =="
( cd "$CD" && ruby -ropenssl -e '
["1204270000Z", "120427000000Z", "990630000000+1000"].each do |s|
  der = "\x17" + [s.length].pack("C") + s
  begin
    OpenSSL::ASN1.decode(der)
    puts "   #{s.ljust(20)} decodes"
  rescue => e
    puts "   #{s.ljust(20)} REFUSED: #{e.message}"
  end
end' )
echo

cat <<'EOF'
============================================================== observed E:
UTCTime without seconds, twice, on a certificate whose two UTCTimes both carry
seconds — and NOT on a certificate whose UTCTime genuinely lacks them.

correct The reverse of both. The 1999 root breaches the zone requirement only,
which certlint reports correctly on the line above. The control breaches the
seconds requirement and should draw this message.

mechanism Two facts that only meet at run time.

1. The regex at lib/certlint/certlint.rb:283-285 tests the zone and the
seconds together:

               if value !~ /\A([0-9]{2})([01][0-9])([0-3][0-9])([012][0-9])([0-5][0-9]){2}Z\z/
                 messages << 'E: UTCTime without seconds'
               end

             The trailing Z\z means a UTCTime with seconds and an offset zone
fails this regex, and draws BOTH this message and the correct 'E: Time not in
Zulu/GMT' from the check five lines above.

2. A UTCTime WITHOUT seconds never reaches line 284 at all. Ruby's
OpenSSL::ASN1 refuses it — 'utctime is too short', shown above — inside
check_pdu, which records
             'F: Decode error in Certificate' at certlint.rb:114. lint() then
             bails at certlint.rb:263:

               # Ensure that we bail on fatal errors
               if messages.any? { |m| m.start_with? 'F:' }
return messages end

             and returns before the time traverse at line 268 begins.

So the check's true population is unreachable and its actual population is the
other message's. Confirmed by execution, not by reading the control flow: the
block-yield order inside OpenSSL::ASN1.traverse is not what it looks like, and
reading it gives the wrong mechanism.

fix Drop the zone from this regex, since the line above already owns that
requirement:

              if value !~ /\A[0-9]{12}(Z|[+-][0-9]{4})\z/

That alone makes the false positives stop. The unreachable half is the harder
one and is not certlint's to fix in this file: while the decoder refuses a
seconds-less UTCTime, no check downstream of check_pdu can see one. Reporting
it would mean recognising the shape inside check_pdu's rescue, where the
message would have to be raised from the decode error rather than from a value
test.
EOF
