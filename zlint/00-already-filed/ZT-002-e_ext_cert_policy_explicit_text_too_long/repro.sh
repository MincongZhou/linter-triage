#!/bin/bash
# ZT-002 — e_ext_cert_policy_explicit_text_too_long measures bytes where RFC
# 6818 §3 states characters.
# lints/rfc/lint_ext_cert_policy_explicit_text_too_long.go: Description:
# "Explicit text has a maximum size of 200 characters", Citation: "RFC 6818:
# 3", if text.Tag == tagBMPString { // ... parse the bytes out into
# UTF-16-BE runes in order to // check their length accurately runes, _ =
# util.ParseBMPString(text.Bytes) } else { runes = string(text.Bytes) } if
# len(runes) > 200 { return &lint.LintResult{Status: lint.Error} } `runes`
# is a Go string, and `len()` on a Go string counts bytes. The BMPString
# branch does not escape this: util.ParseBMPString returns
# string(utf16.Decode(s)), which is UTF-8, so len() counts bytes there too
# -- the comment states the intent the code does not carry out. Executed
# rather than read: "Certificado cualificado para sede electrónica" len=46
# RuneCount=45 BMPString of 3 code points len=6 RuneCount=3 RFC 6818 §3
# gives the bound in characters: "The explicitText field is a string with a
# maximum size of 200 characters." So a conforming explicitText written in
# any language whose text is not pure ASCII is faulted once its UTF-8
# encoding passes 200 octets, which for Spanish or German prose happens a
# few characters early. The two inputs are both real certificates and differ
# in whether the explicitText is over the bound in characters or only in
# bytes. ./positive/ZT-002-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
N=e_ext_cert_policy_explicit_text_too_long

for f in positive/ZT-002-explicittext-200-characters-205-bytes.pem \
         negative/ZT-002-control-explicittext-201-characters.pem ; do
  echo "== $f"
  python3 - "$D/$f" <<'PY'
import sys from cryptography import x509
d = open(sys.argv[1], "rb").read()
c = x509.load_pem_x509_certificate(d)
cp = c.extensions.get_extension_for_class(x509.CertificatePolicies).value
for pi in cp:
    for q in (pi.policy_qualifiers or []):
        if isinstance(q, x509.UserNotice) and q.explicit_text is not None:
            t = q.explicit_text
            print(f"   explicitText: {len(t)} characters, "
                  f"{len(t.encode())} UTF-8 bytes")
            print(f"   {t[:64]!r} ...")
PY
  "$Z" -includeNames="$N" "$D/$f" || echo "   REFUSED"
  echo
done

cat <<'NOTE'

Observed (zlint v3.7.1-20-g1007b1d5):

  200 characters / 205 bytes (bug1536213-crtsh250875409)
      e_ext_cert_policy_explicit_text_too_long   error

  201 characters / 201 bytes (trust-store intermediate-239a0e23591d7413)
      e_ext_cert_policy_explicit_text_too_long   error

Correct: pass on the first, error on the second. The first is inside the bound
the lint's own Description and citation state; only its UTF-8 encoding is over.

The counts are 197 to 200 characters against 202 to 205 bytes, so the whole
population sits within five characters of the bound and is faulted by the
encoding rather than by the text.

Fix: `utf8.RuneCountInString(runes) > 200`. For BMPString the same call is
correct after ParseBMPString, since the decode has already produced code
points. A stricter reading would count UTF-16 code units for BMPString, which
differs only for astral characters that BMPString cannot represent anyway.
NOTE
