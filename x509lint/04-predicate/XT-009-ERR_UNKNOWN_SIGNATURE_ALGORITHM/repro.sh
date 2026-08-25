#!/bin/bash
# XT-009 — "Unkonwn signature algorithm": a typo in x509lint's message
# table. ./positive/XT-009-repro.sh /path/to/x509lint
set -u
X="${1:-x509lint}"
D="$(cd "$(dirname "$0")" && pwd)"

echo "== a certificate whose signature algorithm OpenSSL does not resolve"
"$X" "$D/positive/XT-009-unknown-signature-algorithm.pem" || echo FAILED

cat <<'NOTE'

Observed (x509lint at commit 103c92f) -- the second line is this issue; the
first is an unrelated finding this certificate genuinely earns:

E: Signature algorithm mismatch E: Unkonwn signature algorithm

Correct:

  E: Unknown signature algorithm

The string is a literal in messages.c, in the entry commented
ERR_UNKNOWN_SIGNATURE_ALGORITHM:

  "E: Unkonwn signature algorithm\n", /* ERR_UNKNOWN_SIGNATURE_ALGORITHM */

Raised from CheckSigAlg() at checks.c:2078 and 2084, and from CheckSignature()
at checks.c:2147, when OBJ_obj2nid() or OBJ_find_sigid_algs() cannot resolve
the signature algorithm OID.

No verdict changes: the certificate is reported either way, at the same
severity, from the same branch. It matters only because x509lint has no
identifiers -- the message string IS the key any consumer must match on, so a
typo is load-bearing in a way it would not be in a tool with a lint name.
Correcting it is a breaking change for anything keyed on the current spelling,
which is the argument for doing it once and announcing it rather than never.

Fix: one character in messages.c. NOTE
