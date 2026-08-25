#!/bin/bash
# ZT-057 - GetKeyUsageStrings ranges over a map, so two lints print a
# non-deterministic Details string. util/ku.go:43 func
# GetKeyUsageStrings(keyUsages x509.KeyUsage) []string { var keyUsageStrings
# []string for ku, name := range KeyUsageToString { <- a map if
# KeyUsageIsPresent(keyUsages, ku) { keyUsageStrings =
# append(keyUsageStrings, ...) Go randomises map iteration order
# deliberately, so the slice order is fresh on every call and goes straight
# into a user-visible Details string:
# lints/rfc/lint_key_usage_and_extended_key_usage_inconsistent.go:116
# lints/etsi/lint_qc_np_correct_ku_setting.go:86 The certificate needs three
# or more key usage bits for this to be visible; with one bit there is only
# one ordering. No verdict changes -- the Status is stable and only the
# wording moves. It matters to anyone diffing zlint output between runs,
# which is a real workflow: this was found by a golden-output baseline over
# the reproduction suite in this directory, on its first run.
# ./positive/ZT-057-repro.sh /path/to/zlint [runs]
set -u
Z="${1:-zlint}"
N="${2:-12}"
D="$(cd "$(dirname "$0")" && pwd)"
C="$D/../../00-already-filed/ZT-005-e_key_usage_and_extended_key_usage_inconsist/positive/ZT-005-serverauth-all-three-listed-bits.pem"

echo "== the certificate's key usage, from openssl"
openssl x509 -in "$C" -noout -text | sed -n '/X509v3 Key Usage/,+1p'

echo
echo "== $N runs of the same binary over the same file"
# The histogram itself is random, so this states the property rather than
# the sample: printing counts would make this script's own output differ
# between runs, which is what run.sh --check exists to flag.
DISTINCT=$(for _ in $(seq 1 "$N"); do
  "$Z" -includeNames e_key_usage_and_extended_key_usage_inconsistent "$C" 2>/dev/null \
    | grep -oE 'KeyUsage \[[^]]*\]'
done | sort -u | wc -l)
if [ "$DISTINCT" -gt 1 ]; then
  echo "   distinct orderings of the bit list: MORE THAN ONE -- non-deterministic"
else
  echo "   distinct orderings of the bit list: ONE -- deterministic (fixed?)"
fi

echo
echo "== the status is stable; only the wording moves"
for _ in $(seq 1 "$N"); do
  "$Z" -includeNames e_key_usage_and_extended_key_usage_inconsistent "$C" 2>/dev/null \
    | grep -oE '"result":"[a-z]+"'
done | sort | uniq -c

echo
echo "observed  the bit list is printed in a fresh random order per call, so"
echo "          the same binary on the same certificate emits different"
echo "          Details text between runs."
echo "correct   one ordering. Sort the slice before returning it, or range"
echo "          over an ordered slice of (bit, name) rather than a map."
