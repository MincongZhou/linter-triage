#!/bin/bash
# ZT-084 — e_crl_next_update_invalid takes the validity ceiling from a
# config flag, so a list that says onlyContainsCACerts is judged by the
# subscriber one. bash positive/ZT-084-repro.sh [/path/to/zlint]
set -u
ZLINT="${1:-$HOME/.local/bin/zlint}"
HERE="$(cd "$(dirname "$0")" && pwd)"
echo "zlint: $ZLINT"; echo

echo "== what the list says about itself =="
openssl crl -in "$HERE/positive/ZT-084-arl-only-ca-certs.crl" -inform der -noout -text \
    | sed -n '/Issuing Distribution Point/,+2p' | sed 's/^/   /'
openssl crl -in "$HERE/positive/ZT-084-arl-only-ca-certs.crl" -inform der -noout -text \
    | grep -E 'Last Update|Next Update' | sed 's/^/   /'
echo "   ^ a critical extension saying CA certificates only, and 363 days."
echo

echo "== what zlint says =="
"$ZLINT" -format der -includeNames e_crl_next_update_invalid \
    "$HERE/positive/ZT-084-arl-only-ca-certs.crl" 2>/dev/null | python3 -c "
import sys, json
for k, v in json.load(sys.stdin).items():
    print(f'   {k} = {v[\"result\"]}')
    if v.get('details'): print(f'     {v[\"details\"]}')"
echo

echo "== where that comes from: the shipped default =="
"$ZLINT" -exampleConfig 2>/dev/null | grep -A1 '^\[e_crl_next_update_invalid\]' | sed 's/^/   /'
echo "   ^ every CRL is a Subscriber CRL unless a caller says otherwise."
echo

cat <<'EOF'
==============================================================
observed  e_crl_next_update_invalid = error, "For CRLs covering Subscriber
          Certificates, nextUpdate must be at most 10 days after thisUpdate",
on a list whose critical issuingDistributionPoint asserts onlyContainsCACerts
and whose period is under twelve months.

correct Pass. BR 7.2 gives twelve months for a CRL covering CA Certificates,
and this list states that it is one.

mechanism lint_crl_next_update_invalid.go carries the scope as configuration:

              type CrlNextUpdateInvalid struct {
                  SubscriberCRL bool `comment:"Set this to false if the CRL
                                       to be linted covers CA certificates"`
              }

          Execute() branches on l.SubscriberCRL and never reads
issuingDistributionPoint, which RFC 5280 5.2.5 makes the CRL's own statement
of its population. The shipped default is true, so the answer for an ARL is
wrong unless the caller knew to say so.

pkimetal sets it false for its ARL profiles only, so a *full* CRL covering CA
certificates still gets the subscriber ceiling in production.

severity Medium. It reports a conforming list as violating a requirement, and
it does so for every CA that publishes an ARL without knowing to reconfigure
the linter.

fix Read the extension, and keep the flag as an override for a caller that has
other information:

              only_ca := false
              for _, ext := range c.Extensions {
                  if ext.Id.Equal(util.IssuingDistOID) {
// decode IssuingDistributionPoint, take // onlyContainsCACerts
                  }
              }
              if !only_ca && l.SubscriberCRL { ...10 days... }

A list asserting neither boolean should keep the subscriber ceiling: one that
has not excluded end-entity certificates may hold them.
EOF
