#!/bin/bash
# PT-001 — RFC 6818 replaced RFC 5280's explicitText paragraph with its
# opposite, and pkilint runs both at ERROR with no dates, so every encoding
# but utf8String is an error whichever one it is. bash
# positive/PT-001-repro.sh [python] Needs pkilint importable. Pass the
# interpreter it is installed into as $1; defaults to
# ~/.venv/linters/bin/python.
set -u
PY="${1:-$HOME/.venv/linters/bin/python}"
HERE="$(cd "$(dirname "$0")" && pwd)"

# NOTICE floor: this is about which ERRORs appear, and a floor above them
# would hide the control's silence for the wrong reason.
LINT="$PY -m pkilint.bin.lint_cabf_serverauth_cert lint -d -s NOTICE"

echo "pkilint: $($PY -c 'import pkilint; print(pkilint.__version__)' 2>/dev/null || echo '?')"
echo

cat <<'EOF'
============================================================== the two texts,
which are opposites
============================================================== RFC 5280
s4.2.1.4, May 2008
    "Conforming CAs SHOULD use the UTF8String encoding for explicitText,
     but MAY use IA5String.  Conforming CAs MUST NOT encode explicitText
     as VisibleString or BMPString."

  RFC 6818 s3, January 2013 -- "This paragraph is replaced with:"
    "Conforming CAs SHOULD use the UTF8String encoding for explicitText.
VisibleString or BMPString are acceptable but less preferred alternatives.
Conforming CAs MUST NOT encode explicitText as
     IA5String."

  Replaced, not added alongside. Since 2013-01 the second is the text.
EOF
echo

echo "=============================================================="
echo "all four DisplayText alternatives, identical certificates otherwise"
echo "=============================================================="
printf '  %-16s %-12s %s\n' "fixture" "issued" "what pkilint says"
for f in utf8string ia5string visiblestring bmpstring; do
    said=$($LINT "$HERE/positive/PT-001-$f.pem" 2>&1 \
        | grep -o "pkix.rfc[0-9]*_certificate_policies_invalid_explicit_text_encoding")
    printf '  %-16s %-12s %s\n' "$f" "2025-01-01" "${said:-(nothing)}"
done
echo

echo "-- the full report for the visibleString one --"
$LINT "$HERE/positive/PT-001-visiblestring.pem" 2>&1 | sed 's/^/   /'
echo

cat <<'EOF'
============================================================== observed
DisplayText has exactly four alternatives and three of them are an
          ERROR. utf8String is silent; ia5String draws the RFC 6818 finding;
visibleString and bmpString draw the RFC 5280 one. All four certificates are
issued 2025-01-01, twelve years after RFC 6818 replaced the paragraph -- so
for two of the three, pkilint reports
          at ERROR an encoding the governing text calls "acceptable".

          Measured over a 21,802-certificate corpus: 1,297 draw the
          RFC 5280 finding (987 visibleString, 310 bmpString) and 780 of
those were issued on or after 2013-01-01.

correct Date them, or drop the superseded one. RFC 6818 replaced the paragraph
rather than adding to it, so at most one of the two findings can be right
about any certificate, and which one depends on notBefore. Running both
unconditionally at ERROR makes utf8String the only encoding that satisfies
pkilint, which is neither document's rule.

mechanism CertificatePoliciesUserNoticeValidator.validate, in
pkix/certificate/certificate_extension.py, tests the CHOICE alternative twice
against two disjoint allow-lists:

              if encoding not in ["ia5String", "utf8String"]:
                  ... VALIDATION_EXPLICITTEXT_INVALID_ENCODING_5280
              if encoding not in ["bmpString", "utf8String", "visibleString"]:
                  ... VALIDATION_EXPLICITTEXT_INVALID_ENCODING_6818

          The intersection of the two lists is {utf8String}. Both findings
          are declared ERROR and neither is conditioned on anything.
EOF
