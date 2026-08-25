#!/bin/bash
# ZT-052 — six lints state facts about a keyUsage zcrypto could not decode.
# The certificate's keyUsage extension is 06 03 55 1d 0f 01 01 ff 04 01 d4
# OID 2.5.29.15 critical OCTET STRING { d4 } One raw byte where a DER BIT
# STRING belongs: the 03 02 header is simply absent. zcrypto's decoder
# handles that like this (x509/x509.go, case 15): var usageBits
# asn1.BitString _, err := asn1.Unmarshal(e.Value, &usageBits) if err == nil
# { ... out.KeyUsage = KeyUsage(usage) continue } // no else: out.KeyUsage
# keeps its zero value, and nothing records why Executed against the pinned
# zcrypto rather than inferred: ParseCertificate returns a nil error, the
# extension stays in c.Extensions, and c.KeyUsage is 0b0. There is no third
# state. The neighbouring branch for basicConstraints has one --
# BasicConstraintsValid -- and the keyUsage branch has no equivalent, so
# "asserted no bits" and "could not be read" are the same value. zlint then
# reports, on this certificate: e_ca_key_usage_missing the extension is
# present and critical e_ca_crl_sign_not_set no bit was read, so none is
# known unset e_ca_key_cert_sign_not_set likewise
# e_ext_key_usage_without_bits likewise e_key_usage_incorrect_length a
# length claim about bytes it did not parse e_sub_cert_not_is_ca likewise
# e_ca_key_usage_missing is the plainest: its Description reads "Root and
# Subordinate CA certificate keyUsage extension MUST be present", and its
# Execute is `if c.KeyUsage != 0 { Pass } else { Error }` -- so it reports a
# present extension as absent whenever the value did not decode. zlint holds
# the information needed to stand these down. e_incorrect_ku_encoding
# returns FATAL here and ERROR on the control below, which is the one place
# the distinction survives.
set -u
Z=${ZLINT:-$HOME/.local/bin/zlint}
D=$(dirname "$0")
echo "zlint: $($Z -version 2>&1 | head -1)"

show() {
  $Z "$1" 2>/dev/null | python3 -c '
import json, sys
for k, v in sorted(json.load(sys.stdin).items()):
    if v["result"] in ("error", "fatal"):
        print("    %-6s %s" % (v["result"], k))
'
}

echo
echo "-- the certificate, from Mozilla bug 1742195 --"
openssl x509 -inform DER -in "$D/positive/ZT-052-keyusage-not-a-bit-string.der" \
  -out "$D/.zl043.pem" 2>/dev/null
python3 - "$D/positive/ZT-052-keyusage-not-a-bit-string.der" <<'PY'
import sys, pathlib
b = pathlib.Path(sys.argv[1]).read_bytes()
i = b.find(bytes.fromhex("0603551d0f"))
print("    keyUsage extension as issued:", b[i:i+11].hex())
print("    the extnValue is one byte, d4; a DER BIT STRING header is absent")
PY
show "$D/.zl043.pem"
rm -f "$D/.zl043.pem"

echo
echo "-- control: keyUsage present, well-formed, asserting no bits (03 02 07 00) --"
show "$D/negative/ZT-052-control-keyusage-empty-bit-string.pem"

echo
echo "observed: the two certificates draw the same verdicts, except that"
echo "          e_incorrect_ku_encoding is fatal on the first and error on the"
echo "          control. Five lints state which bits are unset on a value none"
echo "          of them read."
echo "correct : a keyUsage that did not decode is unknown, not empty. The"
echo "          bit-presence lints should not run, and e_ca_key_usage_missing"
echo "          should report the extension as present."
echo "fix     : give zcrypto a KeyUsageValid flag mirroring BasicConstraintsValid,"
echo "          set it in the case 15 branch, and gate the keyUsage lints on it."
echo "          Failing that, test util.IsExtInCert(c, util.KeyUsageOID) rather"
echo "          than c.KeyUsage != 0 for the presence question."
