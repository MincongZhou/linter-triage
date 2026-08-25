#!/bin/bash
# ZT-023 — two lints whose only triggering certificates the parser refuses.
# e_generalized_time_does_not_include_seconds and
# e_generalized_time_includes_fraction_seconds describe a GeneralizedTime
# without seconds, or with a fractional part. zlint ships a fixture for
# each. zcrypto rejects both certificates before any lint runs, so neither
# lint — nor the other 410 — ever executes on them. All three certificates
# here are zlint's own fixtures, copied unmodified.
# ./positive/ZT-023-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"

for f in positive/ZT-023-generalizedtime-no-seconds.pem \
         positive/ZT-023-generalizedtime-fraction-seconds.pem \
         negative/ZT-023-control-generalizedtime-well-formed.pem ; do
  echo "== $f"
  "$Z" "$D/$f" > /tmp/zl011.json 2>/tmp/zl011.err
  if [ $? -eq 0 ]; then
    echo "   parsed; lint results: $(wc -c < /tmp/zl011.json) bytes of JSON"
    echo "   the two lints in question:"
    "$Z" -includeNames=e_generalized_time_does_not_include_seconds,e_generalized_time_includes_fraction_seconds "$D/$f"
  else
    echo "   REFUSED, 0 bytes of JSON:"
    echo "   $(head -c 200 /tmp/zl011.err)"
  fi
  echo
done

cat <<'NOTE'

Observed (zlint v3.7.1-20-g1007b1d5):

  no-seconds       level=fatal ... parsing time "205712010607Z" as
                   "20060102150405Z0700": cannot parse "Z" as "05"
fraction-seconds level=fatal ... asn1: time did not serialize back to the
original value and may be invalid: given
                   "20571201060708.999Z", but serialized as "20571201060708Z"
  control          parses, 22837 bytes of JSON; both lints return pass

Mechanism, zcrypto encoding/asn1/asn1.go:375 —

    func parseGeneralizedTime(bytes []byte) (ret time.Time, err error) {
        const formatStr = "20060102150405Z0700"
        s := string(bytes)
        if ret, err = time.Parse(formatStr, s); err != nil { return }
        if !AllowPermissiveParsing {
            if serialized := ret.Format(formatStr); serialized != s {
                err = fmt.Errorf("asn1: time did not serialize back ...")
            }
        }
        return
    }

The layout requires seconds, so a GeneralizedTime without them fails
time.Parse; the round-trip check rejects a fractional part. zlint never sets
asn1.AllowPermissiveParsing (grep across v3: no occurrence; zcrypto's default
is false), so neither lint has any reachable input.

Neither fixture is referenced by any test — grep for their filenames across
v3/**/*.go returns nothing — and neither lint has a _test.go file at all.

The 225 passes are certificates whose validity
uses GeneralizedTime correctly; nothing else can reach the lint body.

A correct tool would test the two requirements against the raw validity bytes
it already keeps, or accept the certificate in a degraded mode and report the
malformation as a finding. NOTE
