#!/bin/bash
# ZT-009 - e_ext_duplicate_extension lists the duplicated OIDs in a random
# order, because it joins the keys of a map without sorting them.
# lints/rfc/lint_ext_duplicate_extension.go: // If there were duplicates
# turn the map keys into a list so we // can join them for the details
# string. var duplicateOIDsList []string for oid := range duplicateOIDs { //
# a map: random order duplicateOIDsList = append(duplicateOIDsList, oid) }
# ... Details: "The following extensions are duplicated: " +
# strings.Join(duplicateOIDsList, ", "), The comment says the list exists so
# the keys can be joined, and the join is the only use -- so the order is
# purely presentational and purely random. Same root cause as ZT-057, a
# different function. Filed separately because ZT-057 is about
# util.GetKeyUsageStrings and fixing that one does not touch this. Neither
# changes a verdict; both break anything that diffs zlint output.
# ./positive/ZT-009-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
F="$D/positive/ZT-009-zlint-fixture-duplicate-extensions.pem"
N=40 LINT=e_ext_duplicate_extension

echo "== zlint's own fixture multDupeExts.pem, which duplicates two extensions"
echo "   2.5.29.14 subjectKeyIdentifier and 2.5.29.35 authorityKeyIdentifier"
echo
echo "   distinct details strings over $N runs of the same binary:"
for _ in $(seq "$N"); do
  "$Z" -includeNames "$LINT" "$F" 2>/dev/null
done | python3 -c '
import sys, json
seen = set()
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    v = json.loads(line)["'"$LINT"'"]
    seen.add((v["result"], v.get("details", "")))
for r, d in sorted(seen):
    print(f"      {r}  {d}")
print(f"      -> {len(seen)} distinct outcome(s); the result is the same every time")
'
echo
echo "   observed  the same two OIDs in either order."
echo "   correct   one order, every time."
echo
echo "== fix"
echo "   sort.Strings(duplicateOIDsList) before the Join. The list is built"
echo "   solely to be joined, so nothing else depends on its order."
