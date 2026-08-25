#!/bin/bash
# PT-012 — the S/MIME profile detects that a certificate is a CA, says so,
# and then applies every Subscriber requirement to it anyway. bash
# positive/PT-012-repro.sh
set -u
PY="${1:-$HOME/.venv/linters/bin/python}"
HERE="$(cd "$(dirname "$0")" && pwd)"
C="$HERE/positive/PT-012-smime-ca.der"

echo "== the certificate =="
openssl x509 -inform DER -in "$C" -noout -subject -dates 2>/dev/null | sed 's/^/   /'
echo -n "   basicConstraints: "
openssl x509 -inform DER -in "$C" -noout -ext basicConstraints 2>/dev/null | grep -v "^X509v3" | tr -d ' \n'; echo
echo -n "   policy: "
openssl x509 -inform DER -in "$C" -noout -text 2>/dev/null | grep -oE "2\.23\.140\.1\.5\.[0-9.]+" | head -1

echo
echo "== what the S/MIME profile says =="
"$PY" - "$C" <<'EOF' | sed 's/^/   /'
import io, sys from pkilint import loader from pkilint.cabf import smime from
pkilint.cabf.smime import smime_constants
fn = loader.RFC5280CertificateDocumentLoader().get_file_loader_func(loader.DocumentFormat.DER)
c = fn(io.BytesIO(open(sys.argv[1], "rb").read()), sys.argv[1])
print(f"certificate is_ca = {c.is_ca}")
lvl, gen = smime.determine_validation_level_and_generation(c)
print(f"determine_validation_level_and_generation() -> {lvl}, {gen}")
print("  -- a Subscriber validation level and generation, for a CA certificate")
EOF

cat <<'EOF'

============================================================== observed On one
CA certificate the S/MIME profile reports, together:

cabf.smime.is_ca_certificate
cabf.smime.certificate_validity_period_exceeds_825_days
cabf.smime.san_extension_missing cabf.smime.common_name_value_unknown_source
cabf.smime.missing_required_attribute cabf.smime.prohibited_attribute
cabf.smime.multiple_reserved_policy_oids

correct The first finding alone. Once a certificate is known to be a CA it is
not a Subscriber Certificate, and the S/MIME BR Subscriber profile does not
describe it. A five-year validity is ordinary for
          an issuing CA; S/MIME BR § 6.3.2's 825-day ceiling is a Subscriber
          requirement.

mechanism The profile types the certificate into a Subscriber generation --
ORGANIZATION-STRICT, MAILBOX-STRICT and so on -- from its policy OID, raises
cabf.smime.is_ca_certificate because basicConstraints says cA, and then runs
the Subscriber validator set regardless. Detecting the mistyping does not stop
the validations that depend on it being wrong.

fix       When is_ca is true, report cabf.smime.is_ca_certificate and stop.

ORGANIZATION-MULTIPURPOSE 24 MAILBOX-STRICT 17 ORGANIZATION-STRICT 15
MAILBOX-MULTIPURPOSE 10 SPONSORED-STRICT 5 INDIVIDUAL-STRICT 4
SPONSORED-MULTIPURPOSE 3

certificate_validity_period_exceeds_825_days 78 of 78 san_extension_missing 78
of 99 common_name_value_unknown_source 78 of 110 multiple_reserved_policy_oids
40 of 61 missing_required_attribute 40 of 58 prohibited_attribute 31 of 35

EOF
