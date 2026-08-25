#!/bin/bash
# ZT-059 - e_ext_cannot_be_empty_sequence returns inside a map range, so
# when a certificate has two defective extensions it reports a random one of
# them and silently drops the other.
# lints/rfc/lint_ext_cannot_be_empty_seq.go: for extOid := range
# targetExtensionsMap { // a map: random order if ext, found :=
# c.ExtensionsMap[extOid]; found { _, err := asn1.Unmarshal(ext.Value,
# &SequenceOfSomething) if err != nil { return &lint.LintResult{Status:
# lint.Fatal, ...} // returns } if len(SequenceOfSomething) == 0 { return
# &lint.LintResult{Status: lint.Error, ...} // returns } targetExtensionsMap
# holds ten extensions. Go randomises map iteration order on every call, and
# both branches return on the first hit, so which of several defective
# extensions gets reported is decided by a coin toss -- and the rest are
# never reported at all. This is a different defect from ZT-057. There the
# map order changed how a finding was WORDED; here it changes WHICH finding
# you get, and can change the status. The script prints the SET of distinct
# outcomes over many runs, never the counts, because the counts are the
# thing that varies. ./positive/ZT-059-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
N=40 LINT=e_ext_cannot_be_empty_sequence

summarise() {   # $1 = file, $2 = label
  printf '   %s\n' "$2"
  for _ in $(seq "$N"); do
    "$Z" -includeNames "$LINT" "$1" 2>/dev/null
  done | python3 -c '
import sys, json
seen = set()
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    v = json.loads(line)["'"$LINT"'"]
    d = v.get("details", "")
    if d.startswith("Cannot parse the"):
        what = "unparseable " + d.split("the ",1)[1].split(" extension")[0]
    elif d.startswith("The "):
        what = "empty       " + d.split("The ",1)[1].split(" extension")[0]
    else:
        what = ""
    seen.add((v["result"], what))
for r, w in sorted(seen):
    print(f"      {r:<6}{w}")
print(f"      -> {len(seen)} distinct outcome(s) over '"$N"' runs of the same binary")
'
}

echo "== 1. zlint's own fixture, unmodified"
echo "   frshCRLNotCritical.pem carries SubjectInformationAccess and FreshestCRL"
echo "   with byte-identical malformed contents (extnValue 0201 in both), so two"
echo "   of the ten target extensions fail. Only one is ever reported."
summarise "$D/positive/ZT-059-zlint-fixture-two-bad-extensions.pem" "outcomes:"
echo
echo "   observed  the extension NAMED changes between runs."
echo "   correct   a stable report. Both extensions are defective and neither is"
echo "             more the answer than the other -- report both, or iterate in"
echo "             a defined order and say so."
echo
echo "   The corpus has exactly two such certificates and both are zlint's own"
echo "   fixtures: frshCRLCritical.pem and frshCRLNotCritical.pem."

echo
echo "== 2. a constructed certificate, where the STATUS moves too"
echo "   Recipe: a self-signed certificate carrying"
echo "     SubjectInformationAccess = 3000   (a well-formed EMPTY SEQUENCE"
echo "                                        -> parses, len 0 -> lint.Error)"
echo "     FreshestCRL              = 020101 (an INTEGER where a SEQUENCE"
echo "                                        belongs -> lint.Fatal)"
echo "   Whichever the map reaches first decides the status of the whole lint."
summarise "$D/positive/ZT-059-constructed-status-flip.pem" "outcomes:"
echo
echo "   observed  error and fatal, from one binary on one certificate."
echo "   correct   one status, deterministically."
echo
echo "   Two consumers reading this lint disagree about the same certificate,"
echo "   and a re-run disagrees with itself. The empty-SEQUENCE violation is"
echo "   simply not reported on the runs that pick FreshestCRL."

echo
echo "== fix"
echo "   Collect over a sorted key set rather than the map, and accumulate"
echo "   instead of returning on the first hit:"
echo
echo "     oids := make([]string, 0, len(targetExtensionsMap))"
echo "     for oid := range targetExtensionsMap { oids = append(oids, oid) }"
echo "     sort.Strings(oids)"
echo
echo "   Sorting alone makes the report deterministic; accumulating is what"
echo "   makes it complete. util.GetEKUStrings already sorts for exactly this"
echo "   reason -- see ZT-057, which is the same root cause reaching a"
echo "   different part of the output."
