#!/bin/bash
# ZT-081 — an IP address in a dNSName is reported as an invalid TLD, under a
# clause about validating domain authorization, naming a repair that does
# not exist. No zlint lint reports the actual defect.
# ./positive/ZT-081-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
F="$D/positive/ZT-081-ip-address-in-dnsname.pem"

echo "== the certificate's only subjectAltName entry"
openssl x509 -in "$F" -noout -text 2>/dev/null \
  | grep -A1 "Subject Alternative Name" | tail -1 | sed 's/^ */   /'
echo
echo "== zlint, non-passing results"
"$Z" "$F" 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
for k,v in sorted(d.items()):
    if v.get('result') not in ('pass','NA','NE'):
        print(f\"   {v['result']:8} {k}\")
"

cat <<'NOTE'

Observed: e_dnsname_not_valid_tld Correct: a finding that the value is not a
domain name at all.

e_dnsname_not_valid_tld declares:

    Description:   "DNSNames must have a valid TLD."
    Citation:      "BRs: 3.2.2.4"

BR 3.2.2.4 is *Validation of Domain Authorization or Control*. It is about
proving control of a domain name. `213.16.25.173` is not a domain name, so the

The repair the finding names cannot be made. There is no TLD that can be
registered to turn `213.16.25.173` into a conforming dNSName; the value has to
move into an iPAddress entry. A CA reading this finding is told to fix the
wrong thing.

NO LINT REPORTS THE REAL DEFECT. zlint has 33 lints whose names mention a DNS
name and none of them tests whether the value parses as an IP address.
(lint_subject_contains_malformed_arpa_ip and lint_subject_contains_reserved_arpa_ip
parse IPs, but both are about .arpa names, not about an IP literal in a dNSName.)

SEVERITY

Low. The certificate is reported either way and the verdict does not change --
an IP address in a dNSName is non-conforming, and zlint condemns it. What is
wrong is the requirement named and the repair implied.

Reach over the corpus (21,802 certificates): 98 certificates carry a dNSName that
parses as an IP address. 97 draw e_dnsname_not_valid_tld and nothing else about
the IP; the 98th is NE, issued 2012-02-02, before util.CABEffectiveDate -- the
requirement is RFC 5280's and predates the Baseline Requirements, so dating
this lint to the BRs exempts a certificate from a rule that already bound it.

FIX

Two changes, either useful alone:

1. Add a lint for a dNSName that parses as an IP address, citing BR
7.1.2.7.12.

RELATED

NOTE
