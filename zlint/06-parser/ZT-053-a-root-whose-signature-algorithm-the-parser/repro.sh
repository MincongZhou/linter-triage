#!/bin/bash
# ZT-053 - a root CA whose signature algorithm zcrypto declines to recognise is judged under the SUBORDINATE CA profile.  zcrypto sets Certificate.SelfSigned only when the names match AND the self-signature verifies:  if bytes.Equal(out.RawSubject, out.RawIssuer) { if err := out.CheckSignature(...); err == nil { out.SelfSigned = true  and zlint's role predicates are built on that flag alone:  func IsRootCA(c) bool { return IsCACert(c) &&  IsSelfSigned(c) } func IsSubCA(c)  bool { return IsCACert(c) && !IsSelfSigned(c) }  So "I could not check this signature" and "this is not a root" are the same answer. 147 of zlint's 427 lints read one of these predicates. The certificate below reaches that branch through x509.GetSignatureAlgorithmFromAI, which rejects an RSASSA-PSS AlgorithmIdentifier whose hashAlgorithm parameters are ABSENT:  if !bytes.Equal(params.Hash.Parameters.FullBytes, asn1.NullBytes) || ... return UnknownSignatureAlgorithm  RFC 4055 s2.1: "The correct encoding is to omit the parameters field" and "All implementations MUST accept both NULL and absent parameters as legal and equivalent encodings."  Go's own crypto/x509 accepts either, and so does zcrypto's unexported getSignatureAlgorithmFromAI, which CRLs go through:  if (len(params.Hash.Parameters.FullBytes) != 0 && !bytes.Equal(params.Hash.Parameters.FullBytes, asn1.NullBytes)) || ... The two functions live in the same file and disagree. Certificates take the strict one.  ./positive/ZT-053-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
SUBJECT="$D/positive/ZT-053-pss-root-absent-hash-params.pem"          # hashAlgorithm params ABSENT
CONTROL="$D/negative/ZT-053-control-pss-root-null-hash-params.pem"    # hashAlgorithm params NULL

echo "== the two certificates"
echo "   both are publicly trusted roots, both self-signed, both RSASSA-PSS,"
echo "   and both have subject == issuer. They differ in one field."
for f in "$SUBJECT" "$CONTROL"; do
  printf '   %-46s ' "$(basename "$f")"
  openssl x509 -in "$f" -noout -subject | sed 's/.*CN *= *//; s/,.*//'
done

echo
echo "== the field: the hashAlgorithm inside RSASSA-PSS-params"
for f in "$SUBJECT" "$CONTROL"; do
  echo "   $(basename "$f")"
  openssl asn1parse -in "$f" -strparse 4 2>/dev/null \
    | grep -A3 -m1 'rsassaPss' | sed 's/^/      /'
done
echo "   The [0] hashAlgorithm holds 13 octets in the first and 15 in the"
echo "   second: the same id-sha512 OBJECT IDENTIFIER, plus a two-octet"
echo "   NULL (05 00). That NULL is the whole difference between the two"
echo "   certificates as far as this defect is concerned."

echo
echo "== the role each is given, by the lints that only a ROOT can be judged by"
for lint in e_root_ca_key_usage_present e_root_ca_key_usage_must_be_critical \
            e_root_ca_extended_key_usage_present \
            w_root_ca_contains_cert_policy \
            w_root_ca_basic_constraints_path_len_constraint_field_present; do
  a=$("$Z" -includeNames "$lint" "$SUBJECT" | sed -E 's/.*"result":"([a-zA-Z]+)".*/\1/')
  b=$("$Z" -includeNames "$lint" "$CONTROL" | sed -E 's/.*"result":"([a-zA-Z]+)".*/\1/')
  printf '   %-62s absent=%-4s NULL=%s\n' "$lint" "$a" "$b"
done

echo
echo "== and by the lints only a SUBORDINATE CA can be judged by"
for lint in e_sub_ca_certificate_policies_missing e_sub_ca_aia_missing \
            e_sub_ca_crl_distribution_points_missing n_sub_ca_eku_missing \
            w_sub_ca_aia_does_not_contain_issuing_ca_url; do
  a=$("$Z" -includeNames "$lint" "$SUBJECT" | sed -E 's/.*"result":"([a-zA-Z]+)".*/\1/')
  b=$("$Z" -includeNames "$lint" "$CONTROL" | sed -E 's/.*"result":"([a-zA-Z]+)".*/\1/')
  printf '   %-62s absent=%-4s NULL=%s\n' "$lint" "$a" "$b"
done

echo
echo "== a third consequence of the same unrecognised algorithm"
"$Z" -includeNames e_signature_algorithm_not_supported "$SUBJECT" | sed 's/^/   subject: /'
"$Z" -includeNames e_signature_algorithm_not_supported "$CONTROL" | sed 's/^/   control: /'
echo "   Both are SHA-512 RSASSA-PSS. The recognised one warns, which is what"
echo "   zlint means to say about PSS; the unrecognised one errors, because the"
echo "   lint reads c.SignatureAlgorithm and finds UnknownSignatureAlgorithm."

echo
echo "observed  D-TRUST Root CA 1 2017 is judged as a subordinate CA: it is"
echo "          reported for a missing certificatePolicies and a missing AIA,"
echo "          neither of which a root must carry, and the five root-profile"
echo "          lints never run on it at all."
echo "correct   the role is a property of the certificate, not of whether this"
echo "          parser could check its signature. Either give IsRootCA a"
echo "          name-equality path when the signature cannot be checked, or"
echo "          accept absent hashAlgorithm parameters as RFC 4055 s2.1"
echo "          requires -- the one-line form is to use the same condition the"
echo "          unexported sibling in the same file already uses."
