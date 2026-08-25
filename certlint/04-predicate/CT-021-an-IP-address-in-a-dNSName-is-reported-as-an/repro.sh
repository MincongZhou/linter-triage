#!/bin/bash
# CT-021 — an IP address in a dNSName is reported as an unknown top-level
# domain. `iananames.rb` splits on "." and looks the last label up, so
# "213.16.25.173" is a name whose TLD is "173". Certificates: both real,
# from the Bugzilla incident archive. ./positive/CT-021-repro.sh
# /path/to/certlint-checkout
set -u
CL="${1:-.}"
D="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

run() {
  openssl x509 -in "$1" -outform der -out "$T/c.der" 2>/dev/null
  (cd "$CL" && ruby -Ilib -Iext bin/cablint "$T/c.der" 2>/dev/null) | sed 's/\t.*//' \
    | grep -iE "TLD|IP address|domain" || echo "   (nothing about the name)"
}

echo "== SUBJECT: the only subjectAltName is an IP address written as a dNSName"
openssl x509 -in "$D/positive/CT-021-ip-address-in-dnsname.pem" -noout -ext subjectAltName 2>/dev/null \
  | grep -v "^X509v3" | sed 's/^/      /'
run "$D/positive/CT-021-ip-address-in-dnsname.pem" | sed 's/^/   /'

echo
echo "== CONTROL: a dNSName under a top-level domain that has never been delegated"
openssl x509 -in "$D/negative/CT-021-control-genuinely-unknown-tld.pem" -noout -ext subjectAltName 2>/dev/null \
  | grep -v "^X509v3" | cut -c1-100 | sed 's/^/      /'
run "$D/negative/CT-021-control-genuinely-unknown-tld.pem" | sed 's/^/   /'

cat <<'NOTE'

Observed: E: Unknown TLD in SAN, for a dNSName of 213.16.25.173. Correct: a
finding that names the actual defect. RFC 5280 § 4.2.1.6 defines dNSName as an
IA5String holding a domain name and iPAddress as the
          field for an address; BR § 7.1.2.7.12 states the same split. Putting
          an address in a dNSName is non-conforming, and "unknown top-level
          domain" is not what is wrong with it.

The control is the same message earned honestly, so this is the input and not
the check.

THE MECHANISM

    iananames.rb:93   unless fqdn.include? '.'
                        messages << 'E: Unqualified domain name'
    iananames.rb:98   tld = fqdn.split('.').last
    iananames.rb:100  if tld_type.nil?
                        messages << 'E: Unknown TLD'

"213.16.25.173" contains a dot, so it passes the qualification test; its last
label is "173", which no registry carries. Nothing in `IANANames.lint` asks
whether the value is an address, and `IANANames.lint` is called from exactly one
place -- cablint.rb:673, over the SAN's dNSName entries.

SEVERITY: the verdict does not change. cablint condemns the certificate and
the certificate deserves condemning. What is wrong is the requirement named,
which is what a CA reads when deciding what to fix.

REACH

98 certificates over the corpus (21,802) carry a dNSName that parses as an IP
address, and cablint reports every one of them under this message and says
nothing else about the address.

FIX

An address test before the label lookup, and a finding of its own for the real
defect. The address parse has to come first: an IP literal is never a domain
name, so no TLD question arises about it.

THE SAME DEFECT IN THREE IMPLEMENTATIONS

rfc5280/e_dnsname_contains_ip_address, for the actual defect; its corpus total
did not move, because the new rule gained exactly what the old one lost. NOTE
