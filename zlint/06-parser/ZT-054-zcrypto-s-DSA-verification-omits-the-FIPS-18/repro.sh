#!/bin/bash
# ZT-054 - zcrypto's DSA verification omits the FIPS 186-4 hash truncation, so a valid DSA signature fails to verify whenever the digest is longer than q. FIPS 186-4 s4.7 says the verifier uses "the leftmost min(N, outlen) bits of Hash(M)". Go's crypto/dsa does that:  n := pub.Q.BitLen() if n%8 != 0 { return false } n >>= 3 if n > len(hash) { n = len(hash) } z := new(big.Int).SetBytes(hash[:n])  zcrypto's fork keeps the first two lines, drops the other two, and uses the whole digest:  n := pub.Q.BitLen() if n%8 != 0 { return false } z := new(big.Int).SetBytes(hash)  `n` is computed and then never used. For DSA-1024 signed with SHA-256 -- q is 160 bits, the digest 256 -- z is wrong and Verify returns false on a signature that is correct. The visible consequence in zlint is the role: zcrypto sets SelfSigned only when the self-signature verifies, and util.IsRootCA reads nothing else, so this self-signed CA is judged under the SUBORDINATE CA profile. See ZT-053, which is the same misclassification reached through a different parse gap. The certificate is zlint's own fixture, lints/../testdata/dsaCert.pem. The control is that certificate with its last octet flipped, made with: openssl x509 -in positive/ZT-054-dsa-selfsigned.pem -outform der \ | python3 -c 'import sys;d=bytearray(sys.stdin.buffer.read());d[-1]^=0xff;sys.stdout.buffer.write(bytes(d))' \ | openssl x509 -inform der -out negative/ZT-054-control-corrupted-signature.pem It is here to prove the openssl check below is not vacuous -- `openssl verify` does NOT check a trust anchor's own signature unless -check_ss_sig is given.  ./positive/ZT-054-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
C="$D/positive/ZT-054-dsa-selfsigned.pem"
BAD="$D/negative/ZT-054-control-corrupted-signature.pem"

echo "== the certificate"
openssl x509 -in "$C" -noout -subject -issuer | sed 's/^/   /'
openssl x509 -in "$C" -noout -text | grep -E "Signature Algorithm: dsa|Public-Key" | head -2 | sed 's/^/   /'

echo
echo "== an independent verifier on the self-signature, and on a corrupted copy"
printf '   real      : '; openssl verify -check_ss_sig -no_check_time -CAfile "$C" "$C" 2>&1 | tail -1
printf '   corrupted : '; openssl verify -check_ss_sig -no_check_time -CAfile "$BAD" "$BAD" 2>&1 | grep -m1 'error' 

echo
echo "== the role zlint gives it, by lints only a ROOT can be judged by"
for lint in e_root_ca_key_usage_present e_root_ca_extended_key_usage_present \
            w_root_ca_contains_cert_policy; do
  printf '   %-56s %s\n' "$lint" \
    "$("$Z" -includeNames "$lint" "$C" | sed -E 's/.*"result":"([a-zA-Z]+)".*/\1/')"
done

echo
echo "== and by lints only a SUBORDINATE CA can be judged by"
for lint in e_sub_ca_certificate_policies_missing e_sub_ca_aia_missing \
            e_sub_ca_crl_distribution_points_missing; do
  printf '   %-56s %s\n' "$lint" \
    "$("$Z" -includeNames "$lint" "$C" | sed -E 's/.*"result":"([a-zA-Z]+)".*/\1/')"
done

echo
echo "observed  a self-signed DSA CA whose signature openssl verifies is given"
echo "          zcrypto's SelfSigned=false, so the root profile never runs on"
echo "          it and the subordinate profile does."
echo "correct   restore the two dropped lines of crypto/dsa's Verify:"
echo "            n >>= 3; if n > len(hash) { n = len(hash) }"
echo "            z := new(big.Int).SetBytes(hash[:n])"
echo "          FIPS 186-4 s4.7. Verified by executing zcrypto's own Verify"
echo "          twice on this certificate: false with the 32-byte digest,"
echo "          true with it truncated to q's 20 bytes."
