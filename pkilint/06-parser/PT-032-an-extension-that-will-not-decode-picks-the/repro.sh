#!/bin/bash
# PT-032 — a basicConstraints that will not decode moves a CA into the
# subscriber profile, silencing every CA check and inventing subscriber
# ones. bash positive/PT-032-repro.sh [python] Needs pkilint importable.
# Pass the interpreter it is installed into as $1; defaults to
# ~/.venv/linters/bin/python.
set -u
PY="${1:-$HOME/.venv/linters/bin/python}"
HERE="$(cd "$(dirname "$0")" && pwd)"

# -d asks pkilint to type the certificate itself, which is what a caller
# does and is the code path under test. -o prints the type it chose to
# stderr. NOTICE floor so the control's CA findings are visible: at an ERROR
# floor a correctly-typed CA here prints nothing, and "no output" would then
# be indistinguishable from "not linted".
LINT="$PY -m pkilint.bin.lint_cabf_serverauth_cert lint -d -o -s NOTICE"

echo "pkilint: $($PY -c 'import pkilint; print(pkilint.__version__)' 2>/dev/null || echo '?')"
echo

for f in negative/PT-032-control positive/PT-032-pathlen-negative; do
    echo "=============================================================="
    echo "$f.pem"
    echo "=============================================================="
    echo "-- basicConstraints, as OpenSSL reads it --"
    openssl x509 -in "$HERE/$f.pem" -noout -text 2>/dev/null \
        | grep -A1 'X509v3 Basic Constraints' | sed 's/^/   /'
    echo
    echo "-- the type pkilint chose, and what it then said --"
    $LINT "$HERE/$f.pem" 2>&1 | sed 's/^/   /'
    echo
done

echo "=============================================================="
echo "positive/PT-032-undecodable-policies.pem -- the same mechanism, one property over"
echo "=============================================================="
# A real certificate rather than a fabricated one. It asserts
# 2.23.140.1.2.2, organization-validated, and its certificatePolicies will
# not decode -- so cert.policy_oids returns empty and
# _determine_subscriber_certificate_type falls through to its DV default.
# Provenance is in the entry.
echo "-- the policy identifiers, as OpenSSL reads them --"
openssl x509 -in "$HERE/positive/PT-032-undecodable-policies.pem" -noout -text 2>/dev/null \
    | grep 'Policy:' | head -4 | sed 's/^/   /'
echo
echo "-- what pkilint's own accessors return for it --"
"$PY" - "$HERE/positive/PT-032-undecodable-policies.pem" <<'ACCESSORS'
import pathlib import sys

from pkilint import loader

pem = pathlib.Path(sys.argv[1]).read_text()
cert = loader.RFC5280CertificateDocumentLoader().load_pem_document(pem, "subject")
print(f"   policy_oids: {[str(o) for o in cert.policy_oids]}")
print(f"   is_ca:       {cert.is_ca}")
ACCESSORS
echo
echo "-- the type pkilint chose, and what it then said --"
$LINT "$HERE/positive/PT-032-undecodable-policies.pem" 2>&1 | sed 's/^/   /'
echo

echo "=============================================================="
echo "which encodings actually trigger this"
echo "=============================================================="
# Executed, not reasoned about. The claim "pkilint rejects malformed
# basicConstraints" would be far too broad: pyasn1's DER decoder accepts a
# BER BOOLEAN, an explicit DEFAULT, and trailing data without complaint.
# Only the value constraint on pathLenConstraint fires.
"$PY" - <<'PYEOF'
from pyasn1.codec.der.decoder import decode from pyasn1_alt_modules import
rfc5280

cases = [
    ("cA TRUE, pathLenConstraint 5   (DER)", "30060101ff020105"),
    ("cA TRUE, pathLenConstraint 0        ", "30060101ff020100"),
    ("cA TRUE, pathLenConstraint -5       ", "30060101ff0201fb"),
    ("cA encoded 0x01 (BER TRUE, not DER) ", "3006010101020105"),
    ("cA FALSE stated explicitly (DEFAULT)", "3003010100"),
    ("empty SEQUENCE                      ", "3000"),
    ("trailing garbage after the SEQUENCE ", "30060101ff02010500"),
]
for name, hx in cases:
    try:
        v, rest = decode(bytes.fromhex(hx), asn1Spec=rfc5280.BasicConstraints())
        print(f"   accepted  {name}  cA={bool(v['cA'])}")
    except Exception as e:
        print(f"   REJECTED  {name}  {type(e).__name__}")
PYEOF

cat <<'EOF'

============================================================== observed The
two certificates differ in one byte -- 0x05 against 0xfb in the
pathLenConstraint. pkilint types the control INTERNAL-UNCONSTRAINED-TLS-CA and
lints it as a CA. It types the other OV-FINAL-CERTIFICATE -- a subscriber --
and then reports, as ERRORs, that its validity period exceeds 398 days, that
it is missing stateOrProvince and locality, that its commonName has no source
in the SAN, that the SAN extension is absent, and that keyCertSign is a
prohibited key usage. None of those requirements applies to a CA certificate.
Every CA check is skipped in exchange.

correct Treat a basicConstraints that failed to decode as unknown rather than
as absent. pkilint already emits itu.invalid_asn1_syntax for it
          in the same run, so the information exists; what is missing is that
          certificate-type detection consumes the failure as cA=FALSE.

mechanism RFC5280Certificate._decode_and_append_extension catches ValueError
and returns None -- correctly, since a DecodingValidator reports it -- and
is_ca renders that None as False:

              return bool(decoded.navigate("cA").pdu) if decoded else False

determine_certificate_type branches on is_ca, so a CA whose basicConstraints
will not decode is routed to _determine_subscriber_certificate_type.
extended_key_usages has the same shape, returning an empty set on a decode
failure.

          The trigger is narrow, as the table above shows: among the malformed
          encodings tried, only pathLenConstraint < 0 is rejected, because
          RFC 5280 types it INTEGER (0..MAX) and pyasn1 enforces the range.
Self-issued certificates are unaffected -- is_self_issued is tested before
is_ca -- so this reaches intermediates only.
EOF
