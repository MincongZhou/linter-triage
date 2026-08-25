#!/bin/bash
# Run every reproduction for this tool.
#
#     ./run-all.sh /path/to/cablint
#
# Each prints what it observed and what would be correct. A reproduction that
# stops reproducing is information: fixed upstream, tool changed, or the claim
# was wrong.
set -u
T="${1:-cablint}"
D="$(cd "$(dirname "$0")" && pwd)"
n=0
for r in "$D"/*/*/repro.sh; do
    echo
    echo "################ $(basename "$(dirname "$r")")"
    bash "$r" "$T" || echo "  (reproduction exited non-zero)"
    n=$((n+1))
done
echo
echo "$n reproduction(s)"
