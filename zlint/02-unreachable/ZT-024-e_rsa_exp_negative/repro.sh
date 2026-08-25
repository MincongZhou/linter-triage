#!/bin/bash
# ZT-024 — the two RSA structure lints have no reachable input.
# e_rsa_exp_negative ("RSA public key exponent MUST be positive") and
# e_rsa_no_public_key ("The RSA public key should be present") both describe
# a subjectPublicKeyInfo that zcrypto refuses before any lint runs. zcrypto
# x509/x509.go, parsePublicKey, case RSA: p := new(pkcs1PublicKey) rest, err
# := asn1.Unmarshal(asn1Data, p) if err != nil { return nil, err } ... if
# !asn1.AllowPermissiveParsing { if p.N.Sign() <= 0 { return nil,
# errors.New("...modulus...") } if p.E.Sign() <= 0 { return nil,
# errors.New("...exponent...") } } return &rsa.PublicKey{E: p.E, N: p.N},
# nil and the caller at x509.go:1651 returns that error rather than
# recording it. e_rsa_exp_negative fires when key.E is negative. The sign
# check above refuses exactly that certificate. zlint never sets
# asn1.AllowPermissiveParsing, so the guard is always in force.
# e_rsa_no_public_key fires when PublicKeyAlgorithm is RSA and PublicKey is
# not an *rsa.PublicKey. The branch above has two exits, an error and an
# *rsa.PublicKey, and only 1.2.840.113549.1.1.1 reaches it —
# getPublicKeyAlgorithmFromOID maps nothing else to RSA. There is no third
# outcome for the lint to see, with permissive parsing or without. The
# modulus is a conforming 2048 bits in both, so the exponent and the key
# body are the only things that differ from the control, which is the same
# generator's well-formed root. The refusal is the issue, so two of the
# three do not decode. That is stated rather than worked around.
# ./positive/ZT-024-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"

for f in positive/ZT-024-rsa-negative-exponent.pem \
         positive/ZT-024-rsa-key-bits-not-a-key.pem \
         negative/ZT-024-control-rsa-well-formed.pem ; do
  echo "== $f"
  if "$Z" "$D/$f" > /tmp/zl017.json 2> /tmp/zl017.err; then
    echo "   parsed; $(wc -c < /tmp/zl017.json) bytes of JSON"
    echo "   the two lints in question:"
    "$Z" -includeNames=e_rsa_exp_negative,e_rsa_no_public_key "$D/$f"
  else
    echo "   REFUSED, 0 bytes of JSON:"
    echo "   $(head -c 190 /tmp/zl017.err)"
  fi
  echo
done

cat <<'NOTE'

Observed (zlint v3.7.1-20-g1007b1d5):

negative exponent level=fatal ... parsing as certificate: x509: RSA public
exponent is not a positive number key bits not a key level=fatal ... asn1:
structure error: tags don't match
                      (16 vs {class:0 tag:4 ...}) pkcs1PublicKey @2
  control             parses, 21425 bytes of JSON; both lints return pass

The NA count is the
non-RSA keys; the passes are certificates on which the body ran and found the
key it expected. Nothing reaches either Error branch.

Correct: report the malformation as a finding rather than as a refusal, or
delete the lints.

The distinction between the two is worth keeping. e_rsa_exp_negative has a
reachable body under asn1.AllowPermissiveParsing, which exists in zcrypto and
is set nowhere in zlint v3; a caller embedding the library could enable it and
the lint would work. e_rsa_no_public_key would still not fire, because the
branch it needs is not a parse strictness setting but a return type. NOTE
