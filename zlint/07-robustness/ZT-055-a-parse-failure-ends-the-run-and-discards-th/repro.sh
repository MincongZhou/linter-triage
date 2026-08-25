#!/bin/bash
#
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"

echo "== 1. the bad file alone"
"$Z" "$D/positive/ZT-055-printablestring-parse-refusal.pem" > /tmp/zl009a.json 2>/tmp/zl009a.err
if [ $? -eq 0 ]; then echo "   exit: zero"; else echo "   exit: NON-ZERO"; fi
echo "   stdout bytes: $(wc -c < /tmp/zl009a.json)"
echo "   stderr: $(cat /tmp/zl009a.err)"

echo
echo "== 2. a missing file, for comparison of what a consumer can tell apart"
"$Z" "$D/no-such-file.pem" > /tmp/zl009b.json 2>/tmp/zl009b.err
if [ $? -eq 0 ]; then echo "   exit: zero"; else echo "   exit: NON-ZERO"; fi
echo "   stderr: $(cat /tmp/zl009b.err)"

echo
echo "== 3. bad file first, good file second — the good file is never linted"
"$Z" "$D/positive/ZT-055-printablestring-parse-refusal.pem" \
     "$D/../../01-dating/ZT-011-e_excessively-backdated-is-switched-off-by-t/negative/ZT-011-control-backdated-after-sc62.pem" > /tmp/zl009c.json 2>/dev/null
echo "   stdout bytes: $(wc -c < /tmp/zl009c.json)   (a lint report is ~21 kB)"

echo
echo "== 4. good file first, bad file second — the run still aborts"
"$Z" "$D/../../01-dating/ZT-011-e_excessively-backdated-is-switched-off-by-t/negative/ZT-011-control-backdated-after-sc62.pem" \
     "$D/positive/ZT-055-printablestring-parse-refusal.pem" > /tmp/zl009d.json 2>/dev/null
echo "   stdout bytes: $(wc -c < /tmp/zl009d.json)"

cat <<'NOTE'

Observed (zlint v3.7.1-20-g1007b1d5):

  1. exit NON-ZERO, 0 bytes on stdout, and on stderr
       level=fatal msg="unable to parse input as any known type, errors:
         [parsing as certificate: asn1: syntax error:
          PrintableString contains invalid character ...]"
  2. exit NON-ZERO, level=fatal msg="unable to open file ...".
     Same channel, same level, same exit class as (1): a consumer reading the
     exit code cannot tell a nonconformant certificate from a bad path.
3. 0 bytes. The good certificate that followed it was never linted. 4. 21470
bytes — the first file's report — then the process dies.

certlint on the same bytes reports the defect as a finding and continues:
  E: Constraint failure in X520OrganizationName ... (X520OrganizationName.c:115)

A correct tool would emit a JSON object for every input, with a reserved key
(or a fatal-status entry) naming the parse failure, and would carry on to the
next file. As shipped, zlint's most severe class of nonconformity — DER the
parser will not accept — is the one class it cannot report, and a batch
consumer loses both the finding and every file queued behind it. NOTE
