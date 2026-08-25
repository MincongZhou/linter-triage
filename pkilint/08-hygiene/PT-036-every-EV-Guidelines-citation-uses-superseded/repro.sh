#!/bin/bash
# PT-036 — pkilint cites EV Guidelines section numbers that the EV
# Guidelines no longer use. Renumbered by EVG 2.0.0 (ballot SC-062 era
# restructure into the RFC 3647 layout); pkilint 0.13.3 still cites the
# pre-2.0.0 numbers. Needs only pkilint installed. Run:
# ./positive/PT-036-repro.sh # uses python3 ./positive/PT-036-repro.sh
# /path/to/python # the interpreter pkilint is in $1 is the INTERPRETER, not
# a source directory. This script took it as a source directory until
# 2026-08-22, while run.sh has always invoked every reproduction as `bash
# "$s" "$PY"` -- so under the runner it grepped the interpreter path as
# though it were a tree, matched nothing, and recorded the emptiness in
# BASELINE.txt as the expected output. The evidence had been blank for as
# long as the baseline existed, and --check could not see it because the
# blankness was what it compared against.
set -u

PY="${1:-python3}"
SRC=$($PY -c 'import pkilint,pathlib;print(pathlib.Path(pkilint.__file__).parent)' 2>/dev/null) \
  || { echo "pkilint not importable by $PY"; exit 2; }
echo "pkilint source: $SRC"
$PY -c 'import importlib.metadata as m;print("version:", m.version("pkilint"))' 2>/dev/null

echo
echo "== every EV Guidelines citation in the pkilint source =="
grep -rn "EVG [0-9]" --include=*.py "$SRC"

echo
echo "== the same citations as they reach a user, via finding_metadata.csv =="
echo "   (repository file; not shipped in the wheel)"
if [ -f "$SRC/cabf/serverauth/finding_metadata.csv" ]; then
  grep -o "EVG [0-9.]*" "$SRC/cabf/serverauth/finding_metadata.csv" | sort | uniq -c
else
  echo "   (finding_metadata.csv absent from this install)"
fi

cat <<'NOTE'

== what those numbers mean in the EV Guidelines ==

cited as EVG 1.8.1, the last version with that numbering EVG 2.0.3, current
-------- ----------------------------------------------
---------------------------- 9.2 Subject Distinguished Name Fields Financial
responsibility 9.2.3 Subject Business Category Field Insurance or warranty
coverage for end-entities
  9.2.4     Subject Jurisdiction of Incorporation Field     (no such heading)
  9.2.6     Subject Physical Address of Place of Business   (no such heading)
  9.2.8     Subject Organization Identifier Field           (no such heading)
  9.2.9     Other Subject Attributes                        (no such heading)
9.7 Additional Technical Requirements for EV Disclaimers of warranties 9.8
Certificate Extensions Limitations of liability
  9.8.1     Subject Alternative Name Extension              (absent; now 7.1.2.1)
  9.8.2     CA/B Forum Organization Identifier Extension    (absent; now 7.1.2.2)

Verify with:
  grep -nE '^9\.[0-9]'  evg-1.8.1.txt
  grep -nE '^9\.[0-9]'  evg-2.0.3.txt

EVG 2.0.0 moved the certificate profile out of section 9 and restructured the
document into the RFC 3647 layout, in which section 9 is "OTHER BUSINESS AND
LEGAL MATTERS". Six of pkilint's citations no longer resolve at all; four now
resolve to unrelated clauses about financial responsibility, insurance and
warranty disclaimers.

A correct tool would either cite the current numbering (7.1.2.1, 7.1.2.2,
7.1.4.2.x) or pin the version it is quoting, as zlint does:
"CABF EV Guidelines 1.7.8 Section 9.8.1".
NOTE
