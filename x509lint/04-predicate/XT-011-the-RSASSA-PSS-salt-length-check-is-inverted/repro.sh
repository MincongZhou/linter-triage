#!/bin/bash
# XT-011 — the RSASSA-PSS salt-length check demands the wrong length for
# SHA-384 and SHA-512, so it fires on exactly the conforming certificates
# and stays silent on the non-conforming ones. ./positive/XT-011-repro.sh
# /path/to/x509lint
set -u
X="${1:-x509lint}"
D="$(cd "$(dirname "$0")" && pwd)"

for H in 256 384 512; do
  F="$D/positive/XT-011-pss-sha$H.pem"
  echo "== RSASSA-PSS with SHA-$H"
  openssl x509 -in "$F" -noout -text 2>/dev/null \
    | grep -A3 "Signature Algorithm: rsassaPss" | grep -E "Hash Algorithm|Salt Length" \
    | head -2 | sed 's/^ */   /'
  "$X" "$F" 2>/dev/null | grep -E "Invalid PSS salt length" | sed 's/^/   /' \
    || echo "   (no salt-length finding)"
  echo
done

cat <<'NOTE'
Observed (x509lint at commit 103c92f):

  SHA-256, salt 32  ->  no finding                 correct
  SHA-384, salt 48  ->  E: Invalid PSS salt length WRONG -- 48 is required
  SHA-512, salt 64  ->  E: Invalid PSS salt length WRONG -- 64 is required

All three are zlint fixtures from one family, differing in the hash.

THE REQUIREMENT

CA/Browser Forum Baseline Requirements 7.1.3.2.1 enumerates the permitted
RSASSA-PSS parameter sets, and each fixes the salt length to the hash output
length:

RSASSA-PSS with SHA-256, MGF-1 with SHA-256, and a salt length of 32 bytes
RSASSA-PSS with SHA-384, MGF-1 with SHA-384, and a salt length of 48 bytes
RSASSA-PSS with SHA-512, MGF-1 with SHA-512, and a salt length of 64 bytes

MECHANISM

checks.c, CheckPSSSig(), and the comment on the branch cites the clause above:

        if ((hash_nid == NID_sha256 && salt_len != 32)
                || (hash_nid == NID_sha384 && salt_len != 40)
                || (hash_nid == NID_sha512 && salt_len != 48))
        {
                /* BR 7.1.3.2.1 */
                SetError(ERR_PSS_INVALID_SALT_LENGTH);
        }

40 and 48 are wrong. SHA-384 produces 48 bytes and SHA-512 produces 64. The
SHA-256 limb is right, which is why the defect survives casual testing.

The check therefore inverts on two of its three cases. For SHA-384 it can only
fire on a certificate whose salt length is anything other than 48 -- including
every conforming one -- and it cannot fire on a certificate with a salt length
of 40, which is the value the clause forbids. Same for SHA-512 at 48.

REACH (the corpus, 21,802 certificates, x509lint 103c92f)

  9  certificates draw "Invalid PSS salt length"
8 of them are CONFORMING and the finding is false: 4 SHA-384 with a 48-byte
salt 4 SHA-512 with a 64-byte salt 1 is a true finding: SHA-256 with a 17-byte
salt

Two of the eight are not fixtures: a CCADB trust-store root, and a certificate
from a Mozilla CA incident bug. 8 of 9 findings from this check are false.

FIX

        || (hash_nid == NID_sha384 && salt_len != 48)
        || (hash_nid == NID_sha512 && salt_len != 64)
NOTE
