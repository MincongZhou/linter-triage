#!/bin/bash
# CT-025 — "E: RFC822Name has empty value" condemns the zero-length
# rfc822Name excludedSubtree, which is how a CA excludes all Internet mail
# addresses. bash positive/CT-025-repro.sh [/path/to/certlint] Needs ruby
# and certlint's ext/ built.
set -u
CD="${1:-/path/to/certlint}"
HERE="$(cd "$(dirname "$0")" && pwd)"
echo "certlint: $CD"; echo

echo "== the certificate: a zero-length rfc822Name in excludedSubtrees =="
openssl x509 -in "$HERE/positive/CT-025-empty-rfc822-excluded.der" -inform der -noout -text \
    | sed -n '/Name Constraints/,/Signature Algorithm/p' | head -12 | sed 's/^/   /'
( cd "$CD" && ruby -I lib -I ext bin/certlint "$HERE/positive/CT-025-empty-rfc822-excluded.der" 2>&1 ) \
    | grep 'RFC822Name' | sed 's/^/   /'
echo

echo "== executed, not read: the same function on the three constraint forms =="
( cd "$CD" && ruby -I lib -I ext -e '
require "certlint"
["", "example.com", ".example.com", "user@example.com"].each do |v|
  m = CertLint::GeneralNames.rfc822name(v, true)   # true => is_constraint
  puts format("   %-20p %s", v, m.empty? ? "accepted" : m.join("; "))
end' )
echo "   ^ the three non-empty constraint forms of RFC 5280 4.2.1.10 are all"
echo "     accepted, and only the empty one is reported."
echo

cat <<'EOF'
============================================================== observed E:
RFC822Name has empty value, on a CA certificate that excludes all Internet
mail addresses in the standard way.

correct Silence. In excludedSubtrees a zero-length rfc822Name is the
constraint that matches every rfc822Name, which is the only way to
          say "this CA issues no email certificates" in the name-constraints
extension. RFC 5280 4.2.1.10 makes rfc822Name matching a suffix comparison,
and the empty suffix matches everything.

mechanism lib/certlint/generalnames.rb:73-78

              def self.rfc822name(orig_addr, is_constraint = false)
                messages = []
                if orig_addr.nil? || orig_addr.empty?
                  messages << 'E: RFC822Name has empty value'

          is_constraint is threaded through this function and USED, twice,
          for exactly this reason — a constraint may omit the local part
          (line 91) and may carry a leading period (line 103), and certlint
correctly stays silent about both when is_constraint is set. The empty-value
branch above them is the one place the flag is not consulted. The run above
shows the other two working.

          The same shape exists in dnsname() at generalnames.rb:159, whose
empty check likewise precedes every is_constraint test — but a zero-length
dNSName excludedSubtree is equally standard, so that one is worth the same
fix.

severity Medium. It is a false positive on a construct in deliberate wide use,
so it condemns a conformant certificate — and it condemns precisely the CAs
that took the trouble to constrain themselves.

fix       Consult the flag that is already in scope:

              if orig_addr.nil? || (orig_addr.empty? && !is_constraint)
EOF
