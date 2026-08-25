#!/bin/bash
# Verify the package agrees with itself. No linter needed.
#
#     ./check.sh
set -u
D="$(cd "$(dirname "$0")" && pwd)"
fail=0
say() { echo "  $*"; fail=$((fail+1)); }

for tool in zlint pkilint x509lint certlint; do
    m="$D/$tool/MANIFEST.tsv"
    [ -f "$m" ] || { say "$tool: no MANIFEST.tsv"; continue; }
    n=$(tail -n +2 "$m" | wc -l)
    # Contiguous numbering, no holes: the manifest's numbers sorted must be
    # 1..n. A hole would read as material withheld.
    holes=$(tail -n +2 "$m" | cut -f1 | cut -d- -f2 | sort -n | awk -v n="$n" '
        { if ($1+0 != NR) { print NR; exit } } END { if (NR != n) print "count" } ')
    [ -n "$holes" ] && say "$tool: numbering is not 1..$n (first mismatch at $holes)"
    while IFS=$'\t' read -r num group subject sev repro pos neg dir; do
        [ -d "$D/$tool/$dir" ] || { say "$num: $dir missing"; continue; }
        [ -f "$D/$tool/$dir/README.md" ] || say "$num: no README.md"
        [ -d "$D/$tool/$dir/positive" ] || say "$num: no positive/"
        if [ "$repro" = yes ] && [ ! -f "$D/$tool/$dir/repro.sh" ]; then
            say "$num: manifest says repro, none present"
        fi
        if [ "$neg" != 0 ] && [ ! -d "$D/$tool/$dir/negative" ]; then
            say "$num: manifest says $neg control(s), no negative/"
        fi
    done < <(tail -n +2 "$m")
    echo "$tool: $n entries"
done
echo
if [ "$fail" -eq 0 ]; then echo "no problems"; else echo "$fail problem(s)"; fi
exit $((fail > 0))
