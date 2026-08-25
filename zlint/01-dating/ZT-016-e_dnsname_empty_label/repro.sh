#!/bin/bash
# ZT-016 — e_dnsname_empty_label (cabf_br) is dated to the existence of the
# Baseline Requirements rather than to the clause it enforces.
# lints/cabf_br/lint_dnsname_contains_empty_label.go declares EffectiveDate:
# util.CABEffectiveDate, which is 2012-07-01 -- the date the Baseline
# Requirements themselves took effect. The obligation it enforces is
# younger. The dNSName syntax requirement enters the Baseline Requirements
# at v1.6.7, effective 2019-12-19: "Entries in the dNSName MUST be in the
# "preferred name syntax", as specified in RFC 5280, and thus MUST NOT
# contain underscore characters" The preferred name syntax of RFC 1034
# section 3.5 admits no empty label, so that clause is where an empty label
# starts being a Baseline Requirements violation. SC-48 (v1.8.0, 2021-08-25)
# later restated it in terms of LDH Labels; searching for "LDH" finds the
# restatement, not the obligation. Case: an empty label in the commonName,
# issued 2017.
set -u
Z=${ZLINT:-$HOME/.local/bin/zlint}
D=$(dirname "$0")
echo "zlint: $($Z -version 2>&1 | head -1)"
echo
echo "-- observed --"
$Z -includeNames=e_dnsname_empty_label "$D/positive/ZT-016-empty-label-2017.der" 2>/dev/null
openssl x509 -in "$D/positive/ZT-016-empty-label-2017.der" -inform DER -noout -subject -dates 2>/dev/null | sed 's/^/  /'
echo
echo "observed: error, on a certificate issued before the clause existed"
echo "correct : NE (not effective) until 2019-12-19"
echo "fix     : EffectiveDate: the BR 1.6.7 date, not util.CABEffectiveDate"
