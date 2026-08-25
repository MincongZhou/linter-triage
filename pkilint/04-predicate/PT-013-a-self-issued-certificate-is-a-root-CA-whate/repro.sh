#!/bin/bash
# PT-013 — a self-issued certificate is typed ROOT-CA whatever its
# basicConstraints says, so a self-signed end-entity certificate is judged
# against the root CA profile. bash positive/PT-013-repro.sh [python] Needs
# pkilint importable. Pass the interpreter it is installed into as $1;
# defaults to ~/.venv/linters/bin/python.
set -u
PY="${1:-$HOME/.venv/linters/bin/python}"
HERE="$(cd "$(dirname "$0")" && pwd)"

# -d is the code path under test: it is what a caller uses and what its own
# help text describes as detecting the type "from reserved CA/B Forum policy
# OID, EKU(s), name constraints, and basic constraints".
LINT="$PY -m pkilint.bin.lint_cabf_serverauth_cert lint -d -o -s NOTICE"

echo "pkilint: $($PY -c 'import pkilint; print(pkilint.__version__)' 2>/dev/null || echo '?')"
echo

for f in negative/PT-013-control positive/PT-013-self-issued; do
    echo "=============================================================="
    echo "$f.pem"
    echo "=============================================================="
    echo "-- subject, issuer and basicConstraints, as OpenSSL reads them --"
    openssl x509 -in "$HERE/$f.pem" -noout -subject -issuer 2>/dev/null | sed 's/^/   /'
    openssl x509 -in "$HERE/$f.pem" -noout -text 2>/dev/null \
        | grep -A1 'X509v3 Basic Constraints' | sed 's/^/   /'
    echo
    echo "-- the type pkilint chose, and what it then said --"
    $LINT "$HERE/$f.pem" 2>&1 | sed 's/^/   /'
    echo
done

echo "=============================================================="
echo "the two properties, read straight off pkilint's own document"
echo "=============================================================="
"$PY" - "$HERE/positive/PT-013-self-issued.pem" "$HERE/negative/PT-013-control.pem" <<'ACCESSORS'
import pathlib import sys

from pkilint import loader

for path in sys.argv[1:]:
    cert = loader.RFC5280CertificateDocumentLoader().load_pem_document(
        pathlib.Path(path).read_text(), "subject")
    name = pathlib.Path(path).name
    print(f"   {name:26s} is_self_issued={cert.is_self_issued}  is_ca={cert.is_ca}")
ACCESSORS

cat <<'EOF'

============================================================== observed The
two certificates differ in the issuer name and in nothing else. Both carry
basicConstraints cA:FALSE, an EKU of serverAuth, a dNSName SAN and the
domain-validated reserved policy identifier -- subscriber certificates by
every field that declares one. pkilint types the control DV-FINAL-CERTIFICATE
and the self-issued one ROOT-CA, and then reports against the latter that its
validity
          period is below the 8-year root minimum (it is 151 days, which is
          what a subscriber certificate must be), that organizationName is
          absent (a DV subject must not carry one), that the cA bit is not
          set, that root basicConstraints are not present, and that
keyCertSign is not asserted. Every subscriber check is skipped in exchange.

correct Consult basicConstraints before the profile is chosen. RFC 5280
section 4.2.1.9 is explicit that a key whose certificate omits the
          extension or sets cA FALSE "MUST NOT be used to verify certificate
          signatures", so such a certificate is not a CA whatever its issuer
          name is; BR section 7.1.2.1 requires a Root CA certificate to carry
          basicConstraints, critical, with cA TRUE.

mechanism determine_certificate_type tests is_self_issued first and returns
before is_ca is ever read:

              if cert.is_self_issued:
                  return CertificateType.ROOT_CA
              if cert.is_ca:
                  return _determine_intermediate_ca_type(cert)

and is_self_issued is nothing but a DER comparison of the two names:

              return encode(issuer_node.pdu) == encode(subject_node.pdu)

The information is not missing -- the accessor dump above shows is_ca is False
on the same document, and the run itself reports
cabf.serverauth.ca_basic_constraints_ca_bit_not_set from
CaBasicConstraintsValidator. pkilint reads the field that would settle it,
reports it as an error, and does not act on it.
EOF
