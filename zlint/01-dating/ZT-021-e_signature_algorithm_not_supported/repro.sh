#!/bin/bash
# ZT-021 - e_signature_algorithm_not_supported has no effective date in
# either place one can be written, and reports certificates issued before
# the document it cites existed. Citation: "BRs: 6.1.5" EffectiveDate:
# util.ZeroDate func (l *signatureAlgorithmNotSupported) CheckApplies(c
# *x509.Certificate) bool { return true } The Baseline Requirements took
# effect 2012-07-01. **Five of them are dated anyway**, inside CheckApplies:
# e_old_root_ca_rsa_mod_less_than_2048_bits reads `issueDate.Before(
# util.NoRSA1024RootDate)`, and e_rsa_mod_less_than_2048_bits reads
# `util.OnOrAfter(c.NotAfter, util.NoRSA1024Date)`. Those are not defects
# and a sweep that counted them would be reporting a coding style. The claim
# here is that one lint, measured, not a class. ./positive/ZT-021-repro.sh
# /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
N=e_signature_algorithm_not_supported

echo "== the lint's declared source and citation"
"$Z" -list-lints-json | grep -oE "\{\"name\":\"$N\"[^}]*\}" \
  | sed -E 's/.*"citation":"([^"]*)".*"source":"([^"]*)".*/  citation: \1   source: \2/'

echo
echo "== a certificate from 1999, thirteen years before the BRs took effect"
openssl x509 -in "$D/positive/ZT-021-md5-1999.pem" -noout -startdate -subject 2>/dev/null
openssl x509 -in "$D/positive/ZT-021-md5-1999.pem" -noout -text 2>/dev/null | sed -n '/Signature Algorithm/{p;q}'
"$Z" -includeNames "$N" "$D/positive/ZT-021-md5-1999.pem"

echo
echo "observed  error, under a citation to a document published in 2012."
echo "correct   NA. EffectiveDate should be util.CABEffectiveDate"
echo "          (2012-07-01), as the other BR-sourced lints carry."
echo
echo "note      MD5 is genuinely unacceptable; the defect is the citation and"
echo "          the date, not the judgement. RFC 5280 is the document that"
echo "          reaches a 1999 certificate, and it is a different shelf."
