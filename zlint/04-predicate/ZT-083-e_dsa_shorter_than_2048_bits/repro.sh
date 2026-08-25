#!/bin/bash
# ZT-083 — e_dsa_shorter_than_2048_bits tests N >= 244, which is a typo for
# 224, so it reports the first (L, N) pair BR 6.1.5 names. bash
# positive/ZT-083-repro.sh [/path/to/zlint]
set -u
ZLINT="${1:-$HOME/.local/bin/zlint}"
HERE="$(cd "$(dirname "$0")" && pwd)"
echo "zlint: $ZLINT"; "$ZLINT" -version 2>&1 | sed 's/^/   /'; echo

run() {
    "$ZLINT" -includeNames e_dsa_shorter_than_2048_bits,e_dsa_improper_modulus_or_divisor_size \
        "$1" 2>/dev/null | python3 -c "
import sys, json
for k, v in sorted(json.load(sys.stdin).items()):
    print(f'     {k:<40} {v[\"result\"]}')"
}

echo "== L=2048, N=224 — the FIRST pair BR 6.1.5 names =="
python3 - "$HERE/positive/ZT-083-dsa-2048-224.pem" <<'PY'
import re, subprocess, sys
o = subprocess.run(["openssl","x509","-in",sys.argv[1],"-noout","-text"],
                   capture_output=True).stdout.decode()
for lab in ("P:", "Q:"):
    m = re.search(re.escape(lab) + r"\s*\n((?:\s+[0-9a-f:]+\n)+)", o)
    b = bytes.fromhex("".join(m.group(1).replace(":", "").split())).lstrip(b"\x00")
    print(f"   {lab[0]} is {len(b)*8 - (8 - b[0].bit_length())} bits")
PY
run "$HERE/positive/ZT-083-dsa-2048-224.pem"
echo "   ^ one clause, two lints, opposite verdicts on the same certificate."
echo

echo "== the control: L=2048, N=256 — the second pair =="
run "$HERE/negative/ZT-083-control-dsa-2048-256.pem"
echo

echo "== executed, not read: the comparison itself =="
cat <<'GO' | sed 's/^/   /'
lint_dsa_shorter_than_2048_bits.go:59-63

    L := dsaParams.P.BitLen()
    N := dsaParams.Q.BitLen()
    if L >= 2048 && N >= 244 {
        return &lint.LintResult{Status: lint.Pass}
    }
    return &lint.LintResult{Status: lint.Error}
GO
python3 - <<'PY'
print("   224 >= 244 is", 224 >= 244, "-- so a conformant N=224 key takes the error branch")
print("   256 >= 244 is", 256 >= 244, "-- which is why no existing fixture reaches it")
PY
echo

cat <<'EOF'
============================================================== observed
e_dsa_shorter_than_2048_bits = error on a DSA key with L=2048 and N=224, while
e_dsa_improper_modulus_or_divisor_size passes the same certificate.

correct Pass. BRs v1.7.0 6.1.5 names three pairs -- L=2048/N=224, L=2048/N=256
and L=3072/N=256 -- and L=2048/N=224 is the first of them. Both lints cite
that clause.

mechanism lint_dsa_shorter_than_2048_bits.go:62 tests `N >= 244`. FIPS 186-4
          defines N as 160, 224 or 256; 244 is not a value q can take, and
the digits are 224 transposed. Every N below 244 -- which is every conformant
N except 256 -- takes the error branch.

severity Medium. It reports a real requirement's compliant case as a
violation, and it does so on the pair the Baseline Requirements name first. A
CA using L=2048/N=224 -- FIPS 186-4's smaller conformant choice -- is told to
change a key that is correct.

fix       One character.

              if L >= 2048 && N >= 224 {

Or delete the lint: e_dsa_improper_modulus_or_divisor_size states the same
clause completely, and a requirement stated twice is how two implementations
of it come to disagree.
EOF
