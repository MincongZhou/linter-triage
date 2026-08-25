#!/bin/bash
# PT-015 — pkilint types any self-issued certificate as a Root CA before
# asking whether it is a CA at all, then judges it against the Root CA
# profile. bash positive/PT-015-repro.sh
set -u
PY="${1:-$HOME/.venv/linters/bin/python}"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "== the certificate =="
openssl x509 -in "$HERE/positive/PT-015-self-signed-not-a-ca.pem" -noout -subject -issuer 2>/dev/null | sed 's/^/   /'
echo -n "   basicConstraints: "
openssl x509 -in "$HERE/positive/PT-015-self-signed-not-a-ca.pem" -noout -ext basicConstraints 2>/dev/null | grep -v "^X509v3" | tr -d ' \n'
echo "(absent)"
echo
echo "== what pkilint decides, executed =="
"$PY" - "$HERE/positive/PT-015-self-signed-not-a-ca.pem" <<'EOF' | sed 's/^/   /'
import io, re, sys from pkilint import loader from pkilint.cabf import
serverauth
raw = open(sys.argv[1], "rb").read()
m = re.search(rb"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", raw, re.S)
fn = loader.RFC5280CertificateDocumentLoader().get_file_loader_func(loader.DocumentFormat.PEM)
c = fn(io.BytesIO(m.group(0)), sys.argv[1])
print(f"is_self_issued = {c.is_self_issued}")
print(f"is_ca          = {c.is_ca}")
print(f"determine_certificate_type() -> {serverauth.determine_certificate_type(c)}")
EOF

cat <<'EOF'

==============================================================
observed  determine_certificate_type() returns ROOT_CA for a certificate whose
own is_ca property is False, and the Root CA profile's requirements are then
applied to it.

correct   A certificate with no basicConstraints extension is not a CA. RFC
          5280 § 4.2.1.9: "If the basic constraints extension is not present
          ... then the certificate MUST NOT be used as a CA certificate."
Self-issuance is not CA-ness: a self-signed subscriber certificate is an
ordinary, if unusual, end-entity certificate. This one is zlint's own SAN test
fixture.

mechanism pkilint/cabf/serverauth/__init__.py:92

            def determine_certificate_type(cert):
                if cert.is_self_issued:
                    return CertificateType.ROOT_CA
                if cert.is_ca:
                    return _determine_intermediate_ca_type(cert)
                ...

is_self_issued is tested FIRST and is_ca is never consulted for a self-issued
certificate. The two are independent properties and the function treats one as
implying the other.

The clearest consequence is circular: the certificate is typed a Root CA
*because* it is self-issued, and then reported under
cabf.serverauth.root.basic_constraints_extension_absent for lacking the very
extension whose absence means it is not a CA.

fix       Test is_ca first, or require both:

            if cert.is_self_issued and cert.is_ca:
                return CertificateType.ROOT_CA

root.subject_key_identifier_extension_absent 102 residue, 102 not a CA
root.basic_constraints_extension_absent 88 residue, 88 not a CA
root.key_usage_extension_absent 101 residue, 63 not a CA
root.extended_key_usage_extension_present 66 residue, 48 not a CA

          The first two are explained by this defect entirely.
EOF
