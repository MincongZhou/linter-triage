#!/bin/bash
# PT-031 — a keyUsage BIT STRING that will not decode silences every
# keyUsage check, while the certificate visibly violates one. bash
# positive/PT-031-repro.sh [python] Needs pkilint importable. Pass the
# interpreter it is installed into as $1; defaults to
# ~/.venv/linters/bin/python.
set -u
PY="${1:-$HOME/.venv/linters/bin/python}"
HERE="$(cd "$(dirname "$0")" && pwd)"
# Both files go through the same linter, which is what makes the control a
# control. The serverauth linter types each certificate itself with -d.
# NOTICE floor, not ERROR: the control's keyUsage finding is a NOTICE, and
# at an ERROR floor it is filtered out -- which makes the control print "no
# keyUsage finding" for a reason that has nothing to do with the defect. The
# floor has to be low enough that keyUsage machinery running is *visible*,
# otherwise the control demonstrates nothing.
LINT="$PY -m pkilint.bin.lint_cabf_serverauth_cert lint -d -s NOTICE"

echo "pkilint: $($PY -c 'import pkilint; print(pkilint.__version__)' 2>/dev/null || echo '?')"
echo

for f in positive/PT-031-nonminimal-ku negative/PT-031-control; do
    echo "=============================================================="
    echo "$f.pem"
    echo "=============================================================="
    echo "-- keyUsage, as OpenSSL reads it --"
    openssl x509 -in "$HERE/$f.pem" -noout -text 2>/dev/null \
        | grep -A2 'X509v3 Key Usage' | head -3
    echo
    echo "-- pkilint, ERROR floor --"
    $LINT "$HERE/$f.pem" 2>&1 | sed 's/^/   /'
    echo
    echo "-- any keyUsage-derived finding above? --"
    if $LINT "$HERE/$f.pem" 2>&1 | grep -viE 'extended_key_usage|_eku_' | grep -qiE 'ku_present|keycertsign|key_usage'; then
        echo "   YES"
    else
        echo "   NO"
    fi
    echo
done

cat <<'EOF'
============================================================== observed On
positive/PT-031-nonminimal-ku.pem, pkilint raises
          itu.invalid_asn1_syntax (FATAL) for the keyUsage extension and then
reports NO keyUsage-derived finding. The certificate sets keyCertSign, which
the S/MIME BR prohibits in an end-entity certificate, and that goes
unreported.

          The control differs only in that its keyUsage encodes minimally;
          pkilint reads it and its keyUsage checks run.

correct Report the decoding failure AND indicate that keyUsage-dependent
validations were skipped -- or evaluate the bits from the raw octets, which
OpenSSL manages from the same input.

mechanism Every keyUsage check binds pdu_class=rfc5280.KeyUsage. A trailing
zero bit in the named BIT STRING is a DER violation, so the PDU never
materialises, so no validator bound to it is ever offered a node. The result
is indistinguishable from a conforming keyUsage.
EOF
