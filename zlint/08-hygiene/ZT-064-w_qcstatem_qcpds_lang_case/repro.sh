#!/bin/bash
# ZT-064 — w_qcstatem_qcpds_lang_case returns Error, which its own name
# denies, and returns it for something the lint is not about. Name:
# "w_qcstatem_qcpds_lang_case" zlint's contributor guide states the rule
# this breaks: "Lints only return one non-success or non-fatal status, which
# must also match their name prefix." Execute returns two: if len(errString)
# == 0 { if len(wrnString) == 0 { return ...Pass } else { return
# &lint.LintResult{Status: lint.Warn, Details: wrnString} } } else { return
# &lint.LintResult{Status: lint.Error, Details: errString} } `wrnString` is
# the lint's subject -- a PDS language code that is not all lower-case.
# `errString` is `util.ParseQcStatem(...).GetErrorInfo()`, a *decoding*
# failure of the qcStatements extension, which is neither about letter case
# nor about this lint at all: e_qcstatem_qcpds_valid reports the same string
# on the same certificate, under a name that fits it. Certificates: zlint's
# own fixtures, unmodified.
set -u
Z=${ZLINT:-$HOME/.local/bin/zlint}
D=$(dirname "$0")
L=w_qcstatem_qcpds_lang_case,e_qcstatem_qcpds_valid
echo "zlint: $($Z -version 2>&1 | head -1)"
echo

for c in positive/ZT-064-qcpds-bad-encoding negative/ZT-064-control-upper-case-language; do
  echo "$c"
  $Z -includeNames=$L "$D/$c.pem" 2>/dev/null | tr ',' '\n' | sed 's/^/    /'
  echo
done

echo "observed: a lint named w_ returns Error, and returns it for an encoding"
echo "          fault its sibling e_qcstatem_qcpds_valid already reports"
echo "correct : Warn for the language code, and nothing for the encoding --"
echo "          one lint, one status, matching its prefix"
echo "fix     : return Pass when errString is non-empty and leave the encoding"
echo "          to e_qcstatem_qcpds_valid, or rename the lint e_ and drop the"
echo "          Warn branch. The control shows the Warn branch is reachable"
echo "          and correct, so the first is the smaller change."
