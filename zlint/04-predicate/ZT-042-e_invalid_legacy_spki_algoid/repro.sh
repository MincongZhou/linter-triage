#!/bin/bash
# ZT-042 -- e_invalid_legacy_spki_algoid runs the wrong allow-list, because
# it is registered with the wrong constructor.
# lints/cabf_smime_br/lint_invalid_legacy_spki_alogid.go declares its own
# six-entry list -- RSA, P-256, P-384, P-521, Ed25519, Ed448 -- which is
# S/MIME BR s7.1.3.1 as it stood before v1.0.11 added ML-DSA and ML-KEM. Its
# registration then names the other file's constructor:
# lint_invalid_legacy_spki_alogid.go:44 Lint: NewInvalidSPKIAlgoId,
# lint_invalid_spki_algoid.go:43 Lint: NewInvalidSPKIAlgoId, so both lints
# execute InvalidSPKIAlgoId, the TWELVE-entry list.
# NewInvalidLegacySPKIAlgoId, declared ten lines below the registration that
# should name it, has no callers anywhere in the tree. The consequence is
# the whole point of the split: e_invalid_legacy_spki_algoid is the only
# lint that judges a certificate issued between 2023-09-01 and 2025-08-22,
# and in that window it accepts an ML-DSA or ML-KEM key that s7.1.3.1 did
# not yet permit. The file's own header comment states the intent the wiring
# defeats -- "we perform this check taking into account the issuance date
# (notBefore) of the certificate". Certificate: zlint's own fixture
# sm1_alg_mld44_eff1_pqf0.pem -- ML-DSA-44, id-kp-emailProtection, issued
# inside the legacy window ("pqf0" is the fixture family's own marker for
# "before the PQC effective date"). Control: zlint's own
# sm1_alg_p224_eff1_pqfx.pem -- P-224, outside both lists, which the lint
# does report. It proves the lint ran.
set -u
Z=${ZLINT:-$HOME/.local/bin/zlint}
D=$(dirname "$0")
L=e_invalid_legacy_spki_algoid
echo "zlint: $($Z -version 2>&1 | head -1)"
echo

for f in "$D/positive/ZT-042-mldsa44-in-legacy-window.pem" \
         "$D/negative/ZT-042-control-p224.pem"; do
    echo "--- $(basename "$f")"
    echo "issued  : $(openssl x509 -in "$f" -noout -startdate 2>/dev/null | sed 's/^notBefore=//')"
    echo "key     : $(openssl x509 -in "$f" -noout -text 2>/dev/null \
        | grep -m1 'Public Key Algorithm' | sed 's/.*Algorithm: //')"
    $Z -includeNames=$L "$f" 2>/dev/null | tr ',' '\n' | sed 's/^/    /'
    echo
done

echo "observed: pass on the ML-DSA-44 certificate, error on the P-224 one."
echo "          The lint is running; it is running the twelve-entry list."
echo "correct : error on both. ML-DSA is not in s7.1.3.1 as it stood in the"
echo "          window this lint alone judges; v1.0.11 (2025-08-22) added it,"
echo "          and that is where the sibling e_invalid_spki_algoid begins."
echo "fix     : lint_invalid_legacy_spki_alogid.go:44 --"
echo "          Lint: NewInvalidSPKIAlgoId -> Lint: NewInvalidLegacySPKIAlgoId"
echo
echo "The lint's own test file asserts the defective behaviour, which is why"
echo "the suite is green: six cases named *_pqf0 expect Pass where the"
echo "pre-1.0.11 list gives Error."
