#!/bin/bash
# CT-018 — certlint's IANANames.lint returns early on an unknown TLD, so
# every later check on that dNSName is skipped.
# lib/certlint/iananames.rb:100-102 if tld_type.nil? messages << 'E: Unknown
# TLD' return messages Three checks sit after that return and are lost for
# the name: 1. W: Underscore in base domain (line 151) 2. W: Bad IDN A-label
# in DNS Name (line 126) 3. I: Wildcard to immediate left of public suffix
# (lines 141, 148) (1) and (2) survive, because CABLint.lint calls
# CertLint.lint first and GeneralNames.dnsname reports the same two defects
# independently. (3) is reported nowhere else, and is cablint's only signal
# for the shape BR 3.2.2.6 governs — a wildcard in the label immediately
# left of a registry-controlled or public-suffix label. An issuer picks the
# TLD, so an issuer can switch that check off. Two further messages after
# the return are unreachable by this path rather than skipped, and the
# script proves it: see the enumeration at the end. IANANames is called from
# exactly one place, cablint.rb:673, on SAN dNSName entries. `certlint`
# (DER, RFC 5280) never reaches it. ./positive/CT-018-repro.sh
# /path/to/certlint-checkout
set -u
CD="${1:-/path/to/certlint}"
D="$(cd "$(dirname "$0")" && pwd)"
U="$D/positive/CT-018-unknown-tld-skips-name-checks.pem"
K="$D/negative/CT-018-control-known-tld.pem"

echo "== the pair: identical certificates, one label apart"
echo "   unknown  SAN dNSName = $(openssl x509 -in "$U" -noout -ext subjectAltName | tail -1 | tr -d ' ')"
echo "   control  SAN dNSName = $(openssl x509 -in "$K" -noout -ext subjectAltName | tail -1 | tr -d ' ')"
echo "   Both are a wildcard immediately left of the public suffix."

echo
echo "== premise: which of the two TLDs does certlint's bundled data know?"
for t in newtld com; do
  rz=$(grep -c "^${t}\." "$CD/data/root.zone" || true)
  ng=$(grep -ci "^\"${t}\"," "$CD/data/newgtlds.csv" || true)
  echo "   ${t}: root.zone=${rz} newgtlds.csv=${ng}"
done
echo "   newtld is in neither file, so IANANames classifies it nil -> Unknown TLD."

echo
echo "== which command exercises IANANames?"
grep -rn "IANANames.lint" "$CD/lib" || echo FAILED
echo "   one call site, cablint.rb, on SAN dNSName. certlint (DER) never reaches it."

echo
echo "== cablint (PEM, CABF requirements) — unknown TLD:"
( cd "$CD" && ruby -I lib -I ext bin/cablint "$U" ) || echo FAILED
echo
echo "== cablint — control, known TLD:"
( cd "$CD" && ruby -I lib -I ext bin/cablint "$K" ) || echo FAILED

echo
echo "== the contrast, as a diff (control -> unknown; filename column stripped):"
( cd "$CD" && ruby -I lib -I ext bin/cablint "$K" ) | cut -f1 | sort > /tmp/cl002-k.txt
( cd "$CD" && ruby -I lib -I ext bin/cablint "$U" ) | cut -f1 | sort > /tmp/cl002-u.txt
diff /tmp/cl002-k.txt /tmp/cl002-u.txt || true
echo
echo "   OBSERVED: changing the TLD replaces the wildcard finding with"
echo "             'E: Unknown TLD in SAN'. The wildcard is still there and is"
echo "             no longer reported."
echo "   CORRECT:  both findings. An unrecognised TLD makes the public-suffix"
echo "             question harder to answer, not moot; the name is still a"
echo "             wildcard immediately left of the public suffix, and the two"
echo "             statements are independent."

echo
echo "== certlint (DER, RFC 5280 + the ASN.1 grammar) on the same two:"
openssl x509 -in "$U" -outform DER -out /tmp/cl002-u.der
openssl x509 -in "$K" -outform DER -out /tmp/cl002-k.der
echo "-- unknown:"; ( cd "$CD" && ruby -I lib -I ext bin/certlint /tmp/cl002-u.der ) || echo FAILED
echo "-- control:"; ( cd "$CD" && ruby -I lib -I ext bin/certlint /tmp/cl002-k.der ) || echo FAILED
echo "   (both empty: certlint does not lint IANA names, as the grep showed)"

echo
echo "== the mechanism, isolated: the same method with the early return removed"
RB=/tmp/cl002-mech.rb
cat > "$RB" <<'RUBY'
$LOAD_PATH.unshift File.join(ARGV[0], "lib")
require "certlint/iananames"
require "certlint/generalnames"
CertLint::IANANames.load_domains

# Build a copy of IANANames with the two-line early return removed. The
# regex avoids literal quotes so this survives every shell it is pasted
# into.
src = File.read(File.join(ARGV[0], "lib", "certlint", "iananames.rb"))
raise "anchor not found" unless src =~ /E: Unknown TLD.*\n\s*return messages\n/
# Drop the file header: its requires and its __FILE__-relative data path are
# already satisfied by the require above, and __FILE__ is meaningless in
# eval.
src = src[src.index("module CertLint")..-1]
patched = src.sub(/(E: Unknown TLD.*\n)(\s*)return messages\n/) { $1 + $2 + "# early return removed\n" }
patched = patched.sub("module CertLint", "module CertLintPatched")
# load_domains also locates data/ relative to __FILE__; point it at the
# checkout.
patched = patched.sub(/^\s*datadir = .*$/, "      datadir = File.join(ARGV[0], \"data\")")
eval(patched, TOPLEVEL_BINDING)
CertLintPatched::IANANames.load_domains

names = %w[
*.com *.newtld _a.com _a.newtld xn--0.com xn--0.newtld
]
puts format("   %-14s %-44s %-44s %s", "name", "as shipped", "with early return removed", "GeneralNames.dnsname (RFC layer)")
puts "   " + "-" * 156
names.each do |n|
  a = CertLint::IANANames.lint(n.dup)
  b = CertLintPatched::IANANames.lint(n.dup)
  g = CertLint::GeneralNames.dnsname(n.dup)
  d = b - a
  puts format("   %-14s %-44s %-44s %s", n, a.inspect, d.empty? ? "(same)" : "+ " + d.inspect, g.inspect)
end

puts
puts "   Two of the three lost messages are recovered by the RFC layer, in the"
puts "   rightmost column, because CABLint.lint calls CertLint.lint first"
puts "   (cablint.rb:79). The wildcard message is not; it exists only here."

puts
puts "== why the other two post-return messages are unreachable, not skipped"
tlds = CertLint::IANANames.instance_variable_get(:@iana_tlds)
spec = CertLint::IANANames.instance_variable_get(:@special_domains)
orphans = spec.reject { |s| tlds.key?(s.sub(/\A\./, "").split(".").last) }
puts "   E: FQDN under reserved or special domain / N: FQDN under example domain"
puts "     fire only when the name ends in one of #{spec.size} special suffixes."
puts "     Suffixes whose own last label is absent from the TLD table: #{orphans.inspect}"
puts "     — one, a parse artefact of a mangled CSV row containing a space, which"
puts "     cannot appear in a dNSName. Every other special suffix ends in a TLD"
puts "     the table holds, so the unknown-TLD branch is never taken for them."
puts
puts "   I: Domain is bare public suffix"
puts "     needs PublicSuffix::DomainNotAllowed, i.e. a multi-label public suffix,"
puts "     whose TLD is in the list by construction. Never an unknown TLD."

puts
puts "== a second, smaller finding in the same method"
bad = tlds.keys.select { |t| (PublicSuffix.parse("*." + t) && false) rescue true }
puts "   iananames.rb:136-142 rescues PublicSuffix::DomainInvalid with the comment"
puts "   \"We got this far, so assume this is a new tld\". It cannot fire for a new"
puts "   TLD: the early return above it stops any unknown TLD reaching it. The"
puts "   #{bad.size} TLDs that do reach it are all in certlint's table already:"
puts "   #{bad.sort.inspect}"
puts "   They are ccTLDs with a wildcard rule in the public suffix list, not new"
puts "   gTLDs. Removing the early return is also what makes that comment true."
RUBY
ruby "$RB" "$CD" || echo FAILED

cat <<'NOTE'

== provenance

Both certificates are FABRICATED. Recipe, using python3 + cryptography:

  one throwaway RSA-2048 issuer key and one subject key, shared by both certs;
  empty subject; critical SAN carrying a single dNSName; serial 64 bits;
  notBefore 2026-08-01, notAfter 2026-10-01 (61 days, inside the 200-day limit
  in force from 2026-03-15); basicConstraints CA:FALSE critical; keyUsage
  digitalSignature critical; extendedKeyUsage serverAuth; certificatePolicies
  2.23.140.1.2.1; AIA with an OCSP URL and a caIssuers URL; SKI and AKI.
Identical in every field but the SAN dNSName, which is *.newtld in one and
*.com in the other.

They are trimmed to two findings each so the contrast is the whole output.
No corpus certificate was used: this shape does not occur in it (see below).

== reach

0 of 11,717 corpus certificates that Ruby's OpenSSL parses (4 refused).
17,614 SAN dNSNames examined; 9 certificates carry an unknown TLD across 6
distinct TLDs (nas, mcdonalds, ukei, definitelynotagtld, 1, and one with
trailing newlines); none of the nine also carries a wildcard, an underscore
or a malformed A-label, so none loses a finding today.

The issuer chooses the TLD, and the check the TLD switches off is the only one
cablint has for BR 3.2.2.6.

== fix

Replace the early return with a flag, so the name falls through:

    tld_known = !tld_type.nil?
    messages << 'E: Unknown TLD' unless tld_known

and let the rest of the method run. The PublicSuffix rescue below already has
a branch written for exactly this case; today nothing can reach it.
NOTE
