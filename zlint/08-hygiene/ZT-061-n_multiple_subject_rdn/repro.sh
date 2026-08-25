#!/bin/bash
# ZT-061 - six lints carry a Go identifier where a citation belongs. The
# Citation field is human-readable metadata: it tells a reader where a
# requirement comes from, and it is published through -list-lints-json,
# which is how downstream tools build documentation and policy tables.
# Twenty lints take their requirement from the same community source.
# Fourteen cite it as "awslabs certlint". Six cite "lint.AWSLabs certlint" -
# the Go package selector for the source constant, leaked into the string.
# No certificate is needed: the defect is in the tool's own published
# metadata. ./positive/ZT-061-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"

echo "== every citation mentioning certlint, with counts"
"$Z" -list-lints-json | grep -oE '"citation":"[^"]*certlint[^"]*"' | sort | uniq -c

echo
echo "== the six that carry the package selector"
"$Z" -list-lints-json | grep '"citation":"lint.AWSLabs certlint"' \
  | sed -E 's/.*"name":"([^"]+)".*/  \1/'

echo
echo "observed  6 lints cite   lint.AWSLabs certlint"
echo "correct   awslabs certlint, as the other 14 from the same source do"
