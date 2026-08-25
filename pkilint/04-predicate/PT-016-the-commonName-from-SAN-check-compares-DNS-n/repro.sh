#!/bin/bash
# PT-016 — the commonName-from-SAN check compares DNS names
# case-sensitively, so a commonName that differs from a SAN entry only in
# case is reported as having an unknown source. bash
# positive/PT-016-repro.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
C="$HERE/positive/PT-016-cn-case.der"

echo "== the certificate =="
openssl x509 -inform DER -in "$C" -noout -startdate 2>/dev/null | sed 's/^/   /'
echo -n "   subject commonName: "
openssl x509 -inform DER -in "$C" -noout -subject 2>/dev/null | sed 's/^subject=//' | tr ',' '\n' | grep -oP '(?<=CN\s?=\s?).*' | head -1 | xargs
echo "   SAN dNSName entries:"
openssl x509 -inform DER -in "$C" -noout -text 2>/dev/null \
  | grep -A3 "Subject Alternative Name" | tail -n +2 | tr ',' '\n' \
  | grep -oP '(?<=DNS:).*' | head -3 | sed 's/^/     /'
echo
echo "   The commonName and the first SAN entry are the same name."
echo "   They differ only in case."

cat <<'EOF'

==============================================================
observed  cabf.serverauth.subscriber_common_name_unknown_source (ERROR):
          'Unknown source for value of common name: "GBWDC300VG032...."'

correct No finding. The commonName is exactly the first dNSName in the
subjectAltName. DNS names are case-insensitive -- RFC 1035 § 2.3.3
          and RFC 4343, whose title is "Domain Name System (DNS) Case
          Insensitivity Clarification" -- so these are one name, not two.

mechanism pkilint/common/common_name.py:57

            if str(gn_value.pdu) == value_str:

A case-sensitive Python string comparison of the commonName against each SAN
dNSName. BR § 7.1.4.3 requires the commonName value to be
          one of the values in the subjectAltName; it says nothing about byte
casing, and could not, because the two spellings denote the same host.

The IP_ADDRESS branch immediately below compares decoded octets and so has no
equivalent problem. Only the DNS branch is affected.

fix       Casefold both sides of the dNSName comparison:

            if str(gn_value.pdu).lower() == value_str.lower():

          The class is shared. `pkilint/common/common_name.py`'s
CommonNameValidator also backs cabf.smime.common_name_value_unknown_source and
etsi.en_319_412_4.web-4.1.3-4.common_name_unknown_source, so the
          same comparison decides those codes too; only the serverauth code
          was measured here.
EOF
