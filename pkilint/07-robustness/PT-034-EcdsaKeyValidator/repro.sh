#!/bin/bash
# PT-034 — a validator crashes instead of being skipped when the node it
# navigates to failed to decode. The check that dies is, in one case, the
# one the certificate most needs. bash positive/PT-034-repro.sh [python]
set -u
PY="${1:-$HOME/.venv/linters/bin/python}"
HERE="$(cd "$(dirname "$0")" && pwd)"
LINT="$PY -m pkilint.bin.lint_cabf_serverauth_cert lint -d -s ERROR"

for f in positive/PT-034-nonnist-curve positive/PT-034-version4; do
    echo "=============================================================="
    echo "$f.pem"
    echo "=============================================================="
    out=$($LINT "$HERE/$f.pem" 2>&1)
    echo "$out" | grep -E 'Unhandled exception occurred|base.unhandled_exception|invalid_asn1_syntax' \
        | cut -c1-150 | sed 's/^/   /'
    echo "   exit status: $?  (pkilint returns 0 either way)"
    echo "   validators that still reported: $(echo "$out" | grep -cE 'Validator @')"
    echo
done

cat <<'EOF'
==============================================================
observed  base.unhandled_exception (FATAL), from a KeyError inside
document.navigate, and from cryptography rejecting version 4. The validator
raising it produces no finding.

correct Skip a validator whose bound node failed to decode, rather than
letting it navigate into the absent node and raise. pkilint already reports
itu.invalid_asn1_syntax for the same input, so it knows the decode failed
before the validator runs.

why it On positive/PT-034-nonnist-curve.pem the crashing validator is matters
EcdsaKeyValidator, and the certificate is a real CA misissuance whose whole
defect is a non-NIST curve. The check most relevant to that certificate is the
one that died. pkilint is not silent about the certificate -- it reports the
ASN.1 failure and continues with other validators -- but the curve requirement
itself goes unverified, and the finding names a Python node path rather than a
requirement.
EOF
