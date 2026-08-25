#!/bin/bash
# ZT-048 — an iPAddress SAN that is not 4 or 16 octets produces no finding.
# The length constraint is enforced, but by the parser and as a total
# refusal: zcrypto returns "certificate contained IP address of length 3"
# and zlint emits nothing at all. No lint expresses the requirement, so
# there is no finding to report and nothing distinguishes this certificate
# from an unreadable file. Both certificates here are FABRICATED, and are
# self-signed. Built with Go's crypto/x509 CreateCertificate, RSA-2048,
# notBefore 2024-01-01, identical in every field except the SubjectAltName
# extension, which is hand-encoded and passed through ExtraExtensions: three
# octets 30 05 87 03 0a 00 01 (plus the dNSName entry) four octets 30 06 87
# 04 0a 00 00 01 ./positive/ZT-048-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"

for f in positive/ZT-048-san-ip-three-octets.pem negative/ZT-048-control-san-ip-four-octets.pem ; do
  echo "== $f"
  "$Z" "$D/$f" > /tmp/zl014.json 2>/tmp/zl014.err
  if [ $? -eq 0 ]; then
    echo "   parsed, $(wc -c < /tmp/zl014.json) bytes of JSON; findings:"
    tr ',' '\n' < /tmp/zl014.json | grep -Ev '"(NA|NE|pass)"' | sed 's/^/     /'
  else
    echo "   REFUSED, 0 bytes of JSON:"
    echo "   $(head -c 200 /tmp/zl014.err)"
  fi
  echo
done

cat <<'NOTE'

Observed (zlint v3.7.1-20-g1007b1d5):

  three octets  level=fatal msg="unable to parse input as any known type,
                errors: [parsing as certificate: x509: certificate contained
                IP address of length 3 ...]"          0 bytes of JSON
four octets parses, lints, reports e_ext_san_contains_reserved_ip and five
others

Mechanism, zcrypto x509/x509.go:1470 —

    case 7:
        switch len(v.Bytes) {
        case net.IPv4len, net.IPv6len:
            ipAddresses = append(ipAddresses, v.Bytes)
        default:
            err = errors.New("x509: certificate contained IP address of length " + ...)
            return
        }

and zlint never sets asn1.AllowPermissiveParsing, which is the flag that would
route the malformed name into failedToParse instead.

A correct tool would decode the SubjectAltName leniently and report the
non-conforming iPAddress length as a lint result, because "the address is
three octets" is exactly the sort of finding a certificate linter exists to
produce. NOTE
