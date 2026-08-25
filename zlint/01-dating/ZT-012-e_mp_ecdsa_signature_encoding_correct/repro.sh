#!/bin/bash
# ZT-012 - the two MRSP ECDSA encoding lints are dated to MRSP 3.0, but the
# requirement they check entered at MRSP 2.7. util/time.go sets
# MozillaPolicy30Date = 2025-03-15, and both
# e_mp_ecdsa_signature_encoding_correct and
# e_mp_ecdsa_pub_key_encoding_correct carry it as their sole EffectiveDate.
# The clause they enforce -- MRSP 5.1.2, the hex-encoded
# AlgorithmIdentifiers for ECDSA keys and signatures -- first appears in
# MRSP 2.7, effective 2020-01-01, and zlint already defines
# MozillaPolicy27Date for that date and uses it for the two RSA-PSS lints
# drawn from the very same section. MRSP 3.0 changed one thing in that
# clause: it added the P-521 arm. The P-256 and P-384 arms are word-for-word
# what 2.7 published. So 2025-03-15 is the right date for a third of the
# requirement and five years late for the rest. Certificates: real, from
# Mozilla CA compliance bugs.
# positive/ZT-012-p256-key-signed-sha384-2022.pem crt.sh 8146111401, bug
# 1804587. WISeKey issued it deliberately on 2022-12-07 as a negative test,
# expecting its linters to stop it; the incident report says zlint is what
# caught it at the time. Its signature is 70 octets, so the signing key is
# P-256, and the AlgorithmIdentifier is 300a06082a8648ce3d040303 --
# ecdsa-with-SHA384, where MRSP 5.1.2 requires 300a06082a8648ce3d040302.
# negative/ZT-012-control-conformant-after-policy30.pem crt.sh 19749388006,
# bug 1978186, notBefore 2025-07-18. A P-384 key signed with SHA-384, which
# is conformant. It is here to show the lint is willing and able to evaluate
# -- the difference between the two results is the date and nothing else.
# ./positive/ZT-012-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
L=e_mp_ecdsa_signature_encoding_correct

echo "== notBefore 2022-12-07, P-256 key signed with SHA-384"
"$Z" -includeNames="$L" "$D/positive/ZT-012-p256-key-signed-sha384-2022.pem" || echo FAILED
echo "== notBefore 2025-07-18, conformant  (control)"
"$Z" -includeNames="$L" "$D/negative/ZT-012-control-conformant-after-policy30.pem" || echo FAILED
echo
echo "observed  NE on the violation, pass on the control"
echo "correct   error on the violation - MRSP 5.1.2 has bound P-256 and P-384"
echo "          since MRSP 2.7, effective 2020-01-01"
