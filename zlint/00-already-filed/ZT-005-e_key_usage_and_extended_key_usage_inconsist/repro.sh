#!/bin/bash
# ZT-005 — e_key_usage_and_extended_key_usage_inconsistent reports a certificate for which a consistent purpose exists.  lints/rfc/lint_key_usage_and_extended_key_usage_inconsistent.go:  var eku = map[x509.ExtKeyUsage]map[x509.KeyUsage]bool{ x509.ExtKeyUsageServerAuth: { x509.KeyUsageDigitalSignature:                                true, x509.KeyUsageKeyEncipherment:                                 true, x509.KeyUsageKeyAgreement:                                    true, x509.KeyUsageDigitalSignature | x509.KeyUsageKeyEncipherment: true, x509.KeyUsageDigitalSignature | x509.KeyUsageKeyAgreement:    true, }, ... } ... if !eku[extKeyUsage][c.KeyUsage] { return &lint.LintResult{Status: lint.Error, ...} }  The key of that inner map is the whole keyUsage bitmask, so the test is set membership of the exact combination, not "is any asserted bit consistent with a purpose present". A certificate asserting digitalSignature *and* one more bit under id-kp-serverAuth is therefore an Error even though digitalSignature is on the clause's own list for that purpose. RFC 5280 4.2.1.12 states one prohibited state:  If a certificate contains both a key usage extension and an extended key usage extension, then both extensions MUST be processed independently and the certificate MUST only be used for a purpose consistent with both extensions. If there is no purpose consistent with both extensions, then the certificate MUST NOT be used for any purpose.  and the lint's own Description repeats it: "The certificate MUST only be used for a purpose consistent with both key usage extension and extended key usage extension." A certificate with a consistent purpose available is not in that state. Nothing in 4.2.1.12 prohibits asserting a further bit; the "Key usage bits that may be consistent" lines are comments in the clause's ASN.1 and are permissive in form.  ./positive/ZT-005-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
N=e_key_usage_and_extended_key_usage_inconsistent

for f in positive/ZT-005-zlint-fixture-serverauth-plus-nonrepudiation.pem \
         negative/ZT-005-control-zlint-fixture-serverauth-digitalsignature.pem \
         positive/ZT-005-zlint-fixture-multipurpose-plus-dataencipherment.pem \
         positive/ZT-005-serverauth-all-three-listed-bits.pem ; do
  echo "== $f"
  openssl x509 -in "$D/$f" -noout -text 2>/dev/null \
    | grep -A2 -E "X509v3 (Key Usage|Extended Key Usage)" \
    | grep -v -- "--" | sed 's/^/   /'
  "$Z" -includeNames="$N" "$D/$f" || echo "   REFUSED"
  echo
done

cat <<'NOTE'

Observed (zlint v3.7.1-20-g1007b1d5):

  kuEkuInconsistent.pem      KU digitalSignature+nonRepudiation, EKU serverAuth
      error   "KeyUsage [DigitalSignature ContentCommitment] (00000011)
               inconsistent with ExtKeyUsage serverAuth"
kuEkuConsistent.pem KU digitalSignature, EKU serverAuth pass
kuEkuInconsistentMp.pem KU digitalSignature+dataEncipherment, EKU
emailProtection+clientAuth error bug1262610-crtsh13043775 KU
digitalSignature+keyEncipherment+keyAgreement, EKU serverAuth error

Correct: pass on all four.

The first two are zlint's own fixtures for this lint and differ by exactly one
bit. Both assert digitalSignature, which the clause lists for
id-kp-serverAuth, so both are usable for TLS server authentication and neither
is in the state 4.2.1.12 forbids. The lint's own details line prints
DigitalSignature while declaring the certificate inconsistent. The third is
zlint's multi-purpose fixture and has the same shape: digitalSignature is on
the list for both id-kp-emailProtection and id-kp-clientAuth.

The fourth is a real certificate and isolates a second reading inside the same
table. Its three bits -- digitalSignature, keyEncipherment, keyAgreement --
are exactly the three RFC 5280 names for id-kp-serverAuth:

    id-kp-serverAuth             OBJECT IDENTIFIER ::= { id-kp 1 }
-- TLS WWW server authentication -- Key usage bits that may be consistent:
digitalSignature, -- keyEncipherment or keyAgreement

The table enumerates the pairs but not the triple, its comment reading the "or"
as exclusive: "(digitalSignature OR (keyEncipherment XOR keyAgreement))". That
reading is arguable for id-kp-emailProtection, whose comment parenthesises
"(keyEncipherment or keyAgreement)" against an "and/or" earlier in the same
sentence, and it is not supported for id-kp-serverAuth, whose comment has no
such parenthesis. It is recorded here as the sharper half of the same defect
rather than as a separate issue, because the fix below removes both.

299 dataEncipherment 16 keyEncipherment 130 nonRepudiation 10 cRLSign 35
keyCertSign 1 keyAgreement

counted per certificate, so a certificate carrying two surplus bits appears
twice. The other 6 assert only bits that are listed and fail on the exclusive
reading alone. The remaining 3 of the 403 are certificates where no consistent
purpose exists, which is what the clause forbids and what the lint should
report.

Adjacent, and not numbered: two of the six above, crtsh6039677462 and
crtsh6221458302 from bug1793692, carry a keyUsage BIT STRING declaring one
unused bit whose padding bit is set (03 02 01 81). zlint reports that correctly
under e_incorrect_ku_encoding and under e_key_usage_incorrect_length, whose
details say "the key usage ... extension is not parseable" -- and this lint
then computes a finding from the zero mask zcrypto returned, printing
"KeyUsage [] (00000000) inconsistent with ExtKeyUsage ocspSigning". A finding
derived from a value the same run declared unparseable is a smaller problem
than the one recorded here and has not been isolated further.

Fix: key the table on a mask rather than on exact combinations, and test
intersection rather than membership:

    var eku = map[x509.ExtKeyUsage]x509.KeyUsage{
        x509.ExtKeyUsageServerAuth: x509.KeyUsageDigitalSignature |
            x509.KeyUsageKeyEncipherment | x509.KeyUsageKeyAgreement,
        ...
    }
    // union the masks of every tabulated purpose present, then
    if c.KeyUsage & union == 0 { Error }

That is the state the clause and this lint's own Description name, and it
collapses strictPurpose and multiPurpose into one path. A keyUsage bit that no
present purpose lists is a separate observation, and if it is wanted it
belongs to a lint with a w_ or n_ prefix -- the clause does not forbid it, and
reporting it at error condemns certificates that break nothing. NOTE
