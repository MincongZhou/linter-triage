#!/bin/bash
# ZT-069 — e_crl_extensions_validity returns two severities from one
# identifier, and carries no effective date for a table written in 2023.
# bash positive/ZT-069-repro.sh [/path/to/zlint]
set -u
ZLINT="${1:-$HOME/.local/bin/zlint}"
HERE="$(cd "$(dirname "$0")" && pwd)"
echo "zlint: $ZLINT"; echo

echo "== a 2019 revocation list, four years before the table existed =="
openssl crl -in "$HERE/positive/ZT-069-crl-2019.crl" -inform der -noout -text \
    | grep -E 'Last Update|Next Update' | sed 's/^/   /'
"$ZLINT" -format der -includeNames e_crl_extensions_validity \
    "$HERE/positive/ZT-069-crl-2019.crl" 2>/dev/null | python3 -c "
import sys, json
for k, v in json.load(sys.stdin).items():
    print(f'   {k} = {v[\"result\"]}')
    if v.get('details'): print(f'     {v[\"details\"]}')"
echo "   ^ warn, from a lint named e_."
echo

echo "== the metadata, which declares no EffectiveDate at all =="
sed -n '/Name:.*e_crl_extensions_validity/,/},/p' \
    "${2:-/path/to/zlint}/v3/lints/cabf_br/lint_crl_extensions.go" \
    | sed 's/^/   /'
echo

echo "== the two returns, from one Execute =="
sed -n '/func (l \*crlExtensions) Execute/,/^}/p' \
    "${2:-/path/to/zlint}/v3/lints/cabf_br/lint_crl_extensions.go" \
    | grep -E 'lint\.(Warn|Error)|Details' | sed 's/^/   /'
echo

cat <<'EOF'
============================================================== observed
e_crl_extensions_validity returns lint.Warn for an extension outside the table
and lint.Error for a listed extension with the wrong criticality -- two
severities from one identifier -- and it declares no EffectiveDate, so it
judges a 2019 list against a table written by ballot SC-63 in 2023.

correct   Two lints, one per severity, and an EffectiveDate of
          util.CABFBRs_1_8_7_Date (2023-07-15). zlint's own contributor guide
          states the first half: "Lints only return one non-success or
          non-fatal status, which must also match their name prefix."

mechanism lint_crl_extensions.go. The Execute body has two loops: the first
returns Warn for any extension not in allowedExtensions, the second returns
Error for an allowed extension whose Critical does not match the table. The
LintMetadata block carries Name, Description, Citation and Source and no
EffectiveDate, which the framework reads
          as "always".

severity Medium. The date half reports a requirement against lists issued
years before it existed -- the same class the reproduction beside this file
another entry here reports against cablint. The severity half misleads a
consumer selecting by prefix: a caller including
          only `e_` lints gets warnings, and one filtering on severity cannot
          select half a lint.

fix Split the Execute body into two registered lints -- e_ for the criticality
MUST, w_ for the NOT RECOMMENDED row -- and give both

              EffectiveDate: util.CABFBRs_1_8_7_Date,

The value already exists in util/time.go and the sibling CRL lints use it.
EOF
