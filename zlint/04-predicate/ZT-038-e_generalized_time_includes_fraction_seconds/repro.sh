#!/bin/bash
# ZT-038 — e_generalized_time_includes_fraction_seconds reports a fractional second on a certificate that carries none, and its verdict turns on the sign of the UTC offset.  lints/rfc/lint_generalized_time_includes_fraction_seconds.go, checkFraction:  if t.Bytes[len(t.Bytes)-1] == 'Z' { if len(t.Bytes) > 15 { *r = lint.Error } } else if t.Bytes[len(t.Bytes)-5] == '-' || t.Bytes[len(t.Bytes)-1] == '+' { if len(t.Bytes) > 19 { *r = lint.Error } } else { if len(t.Bytes) > 14 { *r = lint.Error } }  The offset branch looks for '-' five octets from the end and for '+' at the last octet. In YYYYMMDDHHMMSS+hhmm the '+' is five octets from the end, so a positive offset misses that branch and falls through to the final one, where every 19-octet offset form is longer than 14 and is reported as a fractional second. A negative offset reaches the branch and passes. The two inputs below differ in exactly one octet. Both certificates are zlint's own well-formed GeneralizedTime fixture — the control ZT-023 uses, shipped as testdata — with the notAfter value rewritten from 20571201060708Z and every enclosing length re-encoded. Nothing else differs from the file zlint ships.  ./positive/ZT-038-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
N=e_generalized_time_includes_fraction_seconds,e_generalized_time_does_not_include_seconds,e_generalized_time_not_in_zulu

for f in positive/ZT-038-generalizedtime-positive-offset.pem \
         negative/ZT-038-control-generalizedtime-negative-offset.pem \
         ../../02-unreachable/ZT-023-e_generalized_time_does_not_include_seconds/negative/ZT-023-control-generalizedtime-well-formed.pem ; do
  echo "== $f"
  echo "   notAfter: $(openssl x509 -in "$D/$f" -noout -enddate 2>/dev/null || echo 'openssl will not read it')"
  "$Z" -includeNames="$N" "$D/$f" || echo "   REFUSED"
  echo
done

cat <<'NOTE'

Observed (zlint v3.7.1-20-g1007b1d5):

notAfter 20571201060708+0500 e_generalized_time_includes_fraction_seconds
error e_generalized_time_does_not_include_seconds pass
e_generalized_time_not_in_zulu error

notAfter 20571201060708-0500 e_generalized_time_includes_fraction_seconds pass
e_generalized_time_does_not_include_seconds pass
e_generalized_time_not_in_zulu error

  notAfter 20571201060708Z   (the fixture as shipped)
      all three pass

Correct: pass on both offset forms. Neither value contains a fractional second
— the seconds field is 08 in both, and what follows is a time differential,
which RFC 5280 4.1.2.5.2 mentions in the same paragraph as a thing a
GeneralizedTime may syntactically include. The nonconformity that is present
is the departure from Zulu, and e_generalized_time_not_in_zulu already reports
it on both.

Two consequences worth separating:

  * The class is a false positive on a shape it does not name, so a consumer
    reading zlint's output learns "fractional seconds" about a certificate
whose seconds are whole. * It is the only reachable path into this lint at
all. ZT-023 records that the parser refuses every certificate carrying a real
fractional second, so the one input that makes the lint fire is the one input
it is not about.

The sibling checkSeconds in lint_generalized_time_does_not_include_seconds.go
carries the same misread index, and is harmless there: its fall-through tests
`len < 14`, which no 19-octet offset form satisfies.

Fix: test for '+' five octets from the end, alongside '-', rather than at the
last octet. NOTE
