#!/bin/bash
# ZT-006 — e_ext_cert_policy_explicit_text_too_long counts UTF-8 bytes where
# RFC 6818 section 3 states a bound in characters.
# lints/rfc/lint_ext_cert_policy_explicit_text_too_long.go: var runes string
# if text.Tag == tagBMPString { runes, _ = util.ParseBMPString(text.Bytes) }
# else { runes = string(text.Bytes) } if len(runes) > 200 { Error } The
# variable is named `runes` and holds a Go string. `len()` on a Go string
# counts UTF-8 bytes, not runes. An explicitText of exactly 200 characters
# containing any non-ASCII character encodes to more than 200 bytes and is
# reported. BOTH arms are affected. util.ParseBMPString returns a string
# too, so the BMPString arm is a byte count as well -- it is not a correct
# branch to copy. The fix is []rune(...) (or utf8.RuneCountInString) on
# both. Case: a real Spanish-language qualified-certificate CPS notice from
# Mozilla bug 1536213. 200 characters; 201+ UTF-8 bytes through its
# diacritics.
set -u
Z=${ZLINT:-$HOME/.local/bin/zlint}
D=$(dirname "$0")
echo "zlint: $($Z -version 2>&1 | head -1)"

echo
echo "-- observed --"
$Z -includeNames=e_ext_cert_policy_explicit_text_too_long \
   "$D/positive/ZT-006-explicittext-200-chars-201-bytes.der" 2>/dev/null

python3 - "$D/positive/ZT-006-explicittext-200-chars-201-bytes.der" <<'PY'
import sys, warnings
warnings.filterwarnings("ignore")
from cryptography import x509
c = x509.load_der_x509_certificate(open(sys.argv[1], "rb").read())
for pi in c.extensions.get_extension_for_class(x509.CertificatePolicies).value:
    for q in (pi.policy_qualifiers or []):
        t = getattr(q, "explicit_text", None)
        if t:
            print(f"  explicitText: {len(t)} characters, {len(t.encode())} UTF-8 bytes")
            print(f"  RFC 6818 bound is 200 characters -> compliant")
PY

echo
echo "observed: error   (a 200-character explicitText reported as too long)"
echo "correct : pass"
echo "fix     : count runes, not bytes, in both arms of the tag switch"
