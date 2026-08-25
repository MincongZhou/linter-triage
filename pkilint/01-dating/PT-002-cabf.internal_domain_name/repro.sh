#!/bin/bash
# PT-002 — cabf.internal_domain_name reports two shapes that are not
# internal names: (a) a nameConstraints dNSName written in the leading-dot
# "subdomains only" form (b) a gTLD that was delegated when the certificate
# was issued and removed later Both are decided by one line in pkilint:
# PublicSuffixList(accept_unknown=False) .publicsuffix(value) is None. The
# list is a current snapshot with no leading-dot handling and no notion of
# when a certificate was issued. bash positive/PT-002-repro.sh
set -u
PY="${1:-$HOME/.venv/linters/bin/python}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"

echo "== (a) the leading-dot form, direct against the library pkilint delegates to =="
"$PY" - <<'EOF' | sed 's/^/   /'
import publicsuffixlist
psl = publicsuffixlist.PublicSuffixList(accept_unknown=False)
for v in (".dell.com", "dell.com", ".vipps.no", "vipps.no"):
    print(f"publicsuffix({v!r:12}) = {psl.publicsuffix(v)!r}")
EOF
cat <<'EOF'

   RFC 5280 §4.2.1.10 gives dNSName constraints as "any DNS name that can be
   constructed by simply adding zero or more labels to the left-hand side" --
   and the leading-dot spelling is the ordinary way CAs write "subdomains
   only". It is a legitimate constraint, not an internal name. 57 corpus
   certificates carry one.

== (b) a gTLD removed AFTER the certificate was issued ==
EOF
C="$ROOT/Mozilla CA incident bug 1795483"
openssl x509 -inform DER -in "$C" -noout -subject -startdate 2>/dev/null | sed 's/^/   /'
openssl x509 -inform DER -in "$C" -noout -text 2>/dev/null | grep -oE "DNS:[a-z.]+" | head -3 | sed 's/^/   /'
"$PY" -c "
import publicsuffixlist
psl = publicsuffixlist.PublicSuffixList(accept_unknown=False)
print('   publicsuffix(%r) = %r' % ('bowel.cancerresearch', psl.publicsuffix('bowel.cancerresearch')))"

cat <<'EOF'

==============================================================
observed  cabf.internal_domain_name (ERROR) on both shapes.

correct   No finding on either. (a) a leading-dot nameConstraints entry is RFC
          5280 §4.2.1.10 syntax (b) .cancerresearch was delegated 2014-07-03
          and removed 2022-10-05; the certificate was issued 2022-07-22, two
and a half months before removal, when the TLD was live in the IANA root zone.

mechanism pkilint/cabf/cabf_name.py:256. VALIDATION_INTERNAL_DOMAIN_NAME is
raised by a container matched on pdu_class=rfc5280.GeneralName, so it also
reaches AIA, CRL-DP and CPS URIs and nameConstraints subtrees -- not only the
CN and SAN the BR definition is scoped to. The test is
          `publicsuffix(value) is None` against a current PSL snapshot, with no
          effective-date logic anywhere in the file.

          BR's definition of Internal Name is a name that "cannot be verified
          as globally unique ... does not end with a TLD registered in IANA's
          Root Zone Database". Whether a TLD was registered is a question with
          a date in it, and the PSL snapshot cannot answer it.

EOF
