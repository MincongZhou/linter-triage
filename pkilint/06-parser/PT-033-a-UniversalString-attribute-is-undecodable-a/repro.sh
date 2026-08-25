#!/bin/bash
# PT-033 — pkilint's DER decoder cannot read ASN.1 tag 0x1C,
# UniversalString, which RFC 5280's own DirectoryString CHOICE admits. The
# whole certificate is refused, so every validator is silenced -- including
# the one that exists to report exactly this encoding. bash
# positive/PT-033-repro.sh [python] Needs pkilint importable. Pass the
# interpreter it is installed into as $1; defaults to
# ~/.venv/linters/bin/python.
set -u
PY="${1:-$HOME/.venv/linters/bin/python}"
HERE="$(cd "$(dirname "$0")" && pwd)"

# ERROR floor: the question is which ERRORs appear. The commonName-present
# WARNING is true of all three fixtures and says nothing about the defect.
LINT="$PY -m pkilint.bin.lint_cabf_serverauth_cert lint -s ERROR -t DV-FINAL-CERTIFICATE"

V="import importlib.metadata as m; print(m.version(\"%s\"))"
echo "pkilint:        $($PY -c "$(printf "$V" pkilint)" 2>/dev/null || echo '?')"
echo "pyasn1_fasder:  $($PY -c "$(printf "$V" pyasn1-fasder)" 2>/dev/null || echo '?')"
echo

cat <<'EOF'
============================================================== the two texts
============================================================== RFC 5280
Appendix A.1
    X520CommonName ::= CHOICE {
          teletexString     TeletexString   (SIZE (1..ub-common-name)),
          printableString   PrintableString (SIZE (1..ub-common-name)),
          universalString   UniversalString (SIZE (1..ub-common-name)),
          utf8String        UTF8String      (SIZE (1..ub-common-name)),
          bmpString         BMPString       (SIZE (1..ub-common-name)) }

  CAB Forum BR s7.1.4.2, Subject attribute table
    commonName | 2.5.4.3 | RFC 5280 | MUST use UTF8String or PrintableString

So universalString is a legal DER encoding that the BRs prohibit -- precisely
the shape cabf.serverauth.attribute_value_invalid_encoding_type exists to
report.
EOF
echo

echo "=============================================================="
echo "the decoder, on the five DirectoryString alternatives"
echo "=============================================================="
$PY - <<'PYEOF' | sed 's/^/  /'
import pyasn1_fasder from pyasn1_alt_modules import rfc5280

cases = {
    "teletexString   (0x14)": bytes([0x14, 0x01, 0x41]),
    "printableString (0x13)": bytes([0x13, 0x01, 0x41]),
    "universalString (0x1C)": bytes([0x1C, 0x04, 0x00, 0x00, 0x00, 0x41]),
    "utf8String      (0x0C)": bytes([0x0C, 0x01, 0x41]),
    "bmpString       (0x1E)": bytes([0x1E, 0x02, 0x00, 0x41]),
}
for label, der in cases.items():
    try:
        pyasn1_fasder.decode_der(der, rfc5280.DirectoryString())
        print(f"{label}: decoded")
    except Exception as e:                                    # noqa: BLE001
        print(f"{label}: REFUSED -- {type(e).__name__}: {e}")
PYEOF
echo

echo "=============================================================="
echo "three certificates, identical but for the commonName encoding"
echo "=============================================================="
printf '  %-18s %-6s %s\n' "fixture" "exit" "what pkilint says at ERROR"
for f in printablestring bmpstring universalstring; do
    said=$($LINT "$HERE/positive/PT-033-$f.pem" 2>&1); rc=$?
    line=$(echo "$said" | grep -oE "cabf\.[a-z_.]+|Failed to load certificate" | head -1)
    printf '  %-18s %-6s %s\n' "$f" "$rc" "${line:-(nothing)}"
done
echo

echo "-- the full report for the universalString one --"
$LINT "$HERE/positive/PT-033-universalstring.pem" 2>&1 \
    | sed "s#$HERE/##" | sed 's/^/   /'
echo

cat <<'EOF'
============================================================== observed
printableString lints clean and exits 0. bmpString draws
cabf.serverauth.attribute_value_invalid_encoding_type and exits 1.
universalString -- the same violation of the same BR row -- is refused at the
TLV header, so pkilint reports nothing about it at all, and exits 1 as well:
the load failure returns a hardcoded 1
          while the exit code otherwise carries the finding count, so
          "unreadable" and "exactly one finding" are the same value.

The refusal is not confined to the attribute. It kills the whole document, so
every other validator pkilint would have run -- extensions, key usage,
validity, SAN -- reports nothing either.

correct Decode UniversalString. It is one of five alternatives RFC 5280 gives
DirectoryString, and the certificate is well-formed DER. Reporting it as a
prohibited encoding is already implemented and
          already correct; the decoder just never lets it get there.

mechanism pyasn1_fasder, pkilint's strict DER decoder, has no case for
UNIVERSAL 28 and raises Pyasn1FasderError while reading the TLV header --
before any CHOICE resolution. pyasn1's own decoder reads the same bytes
without complaint, so this is the fast decoder's tag table and not a pyasn1
limitation. The failure surfaces in pkilint as a ValueError out of the
document loader, which the CLI
          turns into "Failed to load certificate" and an API caller sees as
          an exception rather than an empty finding list.

cabf/serverauth/serverauth_name.py,
AttributeValueDirectoryStringValidator.validate:

              if directory_string_choice_name not in {"utf8String",
                                                      "printableString"}:
                  raise ... VALIDATION_ATTRIBUTE_VALUE_INVALID_ENCODING

          Three alternatives are prohibited by that test. teletexString and
          bmpString reach it; universalString cannot.

EOF
