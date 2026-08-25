#!/bin/bash
# CT-022 — certlint reports an error on every certificate below v3, where
# RFC 5280 4.1.2.1 requires v3 only when extensions are present and
# RECOMMENDS v1 when they are not. bash positive/CT-022-repro.sh
# [/path/to/certlint] Needs ruby and certlint's ext/ built.
set -u
CD="${1:-/path/to/certlint}"
HERE="$(cd "$(dirname "$0")" && pwd)"
echo "certlint: $CD"; echo

show () {
    echo "== $2"
    openssl x509 -inform "$3" -in "$HERE/$1" -noout -subject -dates 2>/dev/null | sed 's/^/   /'
    openssl x509 -inform "$3" -in "$HERE/$1" -noout -text 2>/dev/null \
        | grep -E '^ +Version:' | sed 's/^ */   /'
    if openssl x509 -inform "$3" -in "$HERE/$1" -noout -text 2>/dev/null | grep -q 'X509v3 '; then
        echo "   extensions: present"
    else
        echo "   extensions: NONE"
    fi
    ( cd "$CD" && ruby -I lib -I ext bin/certlint "$HERE/$1" 2>&1 ) \
        | grep -i 'version' | sed 's/^/   /'
    echo
}

show positive/CT-022-v1-no-extensions-verisign-1996.der \
     "v1, no extensions — VeriSign Class 1 Public Primary CA, 1996" der
show positive/CT-022-v2-uniqueid-no-extensions.pem \
     "v2, unique identifiers, no extensions" pem
show negative/CT-022-control-v3-with-extensions.der \
     "control: v3 with extensions — nothing reported" der

cat <<'EOF'
==============================================================
observed  E: Old certificate version (not X.509v3)

on a 1996 v1 root with no extensions, and on a v2 certificate carrying unique
identifiers and no extensions.

correct   No finding on either. RFC 5280 4.1.2.1:

            "When extensions are used, as expected in this profile, version
             MUST be 3 (value is 2).  If no extensions are present, but a
             UniqueIdentifier is present, the version SHOULD be 2 (value is
             1); however, version MAY be 3.  If only basic fields are present,
             the version SHOULD be 1 (the value is omitted from the
             certificate as a default value); however, the version MAY be 2
             or 3."

The v3 requirement is CONDITIONAL on extensions being present. For a
certificate with none, v1 is what the RFC recommends, and for one with unique
identifiers and no extensions, v2 is. certlint reports an error for doing
exactly what the clause recommends.

mechanism lib/certlint/certlint.rb:356-360 tests cert.version alone:

              if cert.version > 2
                messages << 'E: Invalid certificate version'
              elsif cert.version < 2
                messages << 'E: Old certificate version (not X.509v3)'
              end

Neither limb consults the extension list. The sibling message on the other
limb is correct — there is no version above 3 — which is why this is a missing
condition and not a misread clause.

fix       Gate the second limb on the extension list:

              elsif cert.version < 2 && cert.extensions.any?

which leaves the correct finding — extensions present below v3 — and drops the
recommendation-following case. A tool wanting to say something about the v1
roots should say it as a notice, since RFC 5280 states no requirement they
breach.
EOF
