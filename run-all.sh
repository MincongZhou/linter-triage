#!/bin/bash
# Run every reproduction in the package.
#
#     ./run-all.sh zlint /path/to/lint_cabf_serverauth_cert x509lint cablint
#
# Any tool you leave out is skipped. Each reproduction prints what it observed
# and what would be correct.
set -u
D="$(cd "$(dirname "$0")" && pwd)"
for pair in "zlint:${1:-}" "pkilint:${2:-}" "x509lint:${3:-}" "certlint:${4:-}"; do
    tool="${pair%%:*}"; bin="${pair#*:}"
    if [ -z "$bin" ]; then echo "skipping $tool (no binary given)"; continue; fi
    echo; echo "================================================ $tool"
    bash "$D/$tool/run-all.sh" "$bin"
done
