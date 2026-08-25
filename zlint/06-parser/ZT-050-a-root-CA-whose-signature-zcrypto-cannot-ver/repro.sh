#!/bin/bash
# ZT-050 — a root CA whose signature zcrypto cannot verify is linted as a
# subordinate CA. An id-RSASSA-PSS subjectPublicKeyInfo is enough to trigger
# it. util/ca.go decides the whole CA profile on one boolean: func
# IsRootCA(c *x509.Certificate) bool { return IsCACert(c) && IsSelfSigned(c)
# } func IsSubCA(c *x509.Certificate) bool { return IsCACert(c) &&
# !IsSelfSigned(c) } func IsSelfSigned(c *x509.Certificate) bool { return
# c.SelfSigned } and zcrypto sets SelfSigned only when the self-signature
# *verifies*: if bytes.Equal(out.RawSubject, out.RawIssuer) { if err :=
# out.CheckSignature(out.SignatureAlgorithm, out.RawTBSCertificate,
# out.Signature); err == nil { out.SelfSigned = true } } For a certificate
# whose SPKI names id-RSASSA-PSS (1.2.840.113549.1.1.10) rather than
# rsaEncryption, that check cannot succeed, because zcrypto does not
# recognise the key at all: func getPublicKeyAlgorithmFromOID(oid
# asn1.ObjectIdentifier) PublicKeyAlgorithm { switch { case
# oid.Equal(oidPublicKeyRSA): return RSA ... } return
# UnknownPublicKeyAlgorithm } oidSignatureRSAPSS is in the same file; the
# OID is simply absent from the key side of it. c.PublicKey stays nil,
# CheckSignature returns "algorithm unimplemented", SelfSigned stays false,
# and IsSubCA is true. Executed against the pinned zcrypto rather than
# inferred: SelfSigned=false IsCA=true sigAlgo=0(0)
# pubAlgo=unknown_algorithm CheckSignature against own key: x509: cannot
# verify signature: algorithm unimplemented openssl verify -check_ss_sig on
# the same file reports OK, so the signature is sound and only zcrypto
# declines to read it. The certificate is D-TRUST Root CA 1 2017, a root.
# Every root-CA lint reports NA on it and the subordinate-CA profile is
# applied instead. ./positive/ZT-050-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
N=e_root_ca_key_usage_present,e_root_ca_extended_key_usage_present,e_sub_ca_aia_missing,e_sub_ca_certificate_policies_missing,e_sub_ca_crl_distribution_points_missing

for f in positive/ZT-050-root-ca-rsassa-pss-spki.pem \
         negative/ZT-050-control-root-ca-rsaencryption.pem ; do
  echo "== $f"
  openssl x509 -in "$D/$f" -noout -subject 2>/dev/null | sed 's/^/   /'
  openssl x509 -in "$D/$f" -noout -text 2>/dev/null \
    | grep -m1 'Public Key Algorithm' | sed 's/^/  /'
  echo -n "   openssl verify -check_ss_sig: "
  openssl verify -check_ss_sig -CAfile "$D/$f" "$D/$f" >/dev/null 2>&1 \
    && echo "self-signature OK" || echo "self-signature not confirmed (may be expiry)"
  "$Z" -includeNames="$N" "$D/$f" || echo "   REFUSED"
  echo
done

cat <<'NOTE'

Observed (zlint v3.7.1-20-g1007b1d5):

D-TRUST Root CA 1 2017, SPKI id-RSASSA-PSS, subject == issuer
e_root_ca_key_usage_present NA e_root_ca_extended_key_usage_present NA
e_sub_ca_aia_missing error e_sub_ca_certificate_policies_missing error

Network Solutions Certificate Authority, SPKI rsaEncryption, subject == issuer
e_root_ca_key_usage_present pass e_sub_ca_aia_missing NA
e_sub_ca_certificate_policies_missing NA

Correct: the root profile on both. A root CA is not required to carry
authorityInformationAccess or certificatePolicies -- BR 7.1.2.10 lists both as
NOT RECOMMENDED for Root CA Certificates -- and the two errors above are
requirements from the Subordinate CA profile applied to a certificate that is
not one.

zlint separately, and correctly, reports e_public_key_type_not_allowed and
e_signature_algorithm_not_supported on the same certificate. Nothing here
disputes those: an id-RSASSA-PSS SPKI is prohibited by Mozilla Root Store
Policy 5.1.1 and outside the BR's algorithm table. The defect is that the
prohibited encoding also silently changes which profile the certificate is
linted against, so the tool reports the Subordinate CA requirements and stays
silent on every Root CA one.

This is the shape README.md calls the serious one: the subject of the check
controls whether the check runs. Any self-issued CA whose signature zcrypto
declines -- an unrecognised key OID, an unrecognised signature OID, or a
signature that genuinely does not verify -- is silently promoted into the
subordinate-CA profile, and no lint says so.

Reach: 1 of the 21,778 corpus certificates has an id-RSASSA-PSS SPKI and is a
CA (Mozilla CA incident bug 1917405, this file). Two further
trust-store roots reach the same state by the other route --
 (Vintegris) and
root-c34c5df53080078f.der (CCA India 2015 SPL) -- whose self-signatures do not
verify under openssl either, so for those two IsSubCA is doing what it
documents. Three roots in all are linted as subordinate CAs.

Case: Mozilla CA incident bug 1917405 Control: , chosen because it is a root
with no authorityInformationAccess, so the sub-CA lints report NA on it rather
than pass -- the classification, not the extension, is what differs.

Fix: add oidPublicKeyRSAPSS to getPublicKeyAlgorithmFromOID in zcrypto,
parsing the key as RSA -- RFC 4055 3.1 states the subjectPublicKey for
id-RSASSA-PSS is an RSAPublicKey, so nothing else changes. Independently of
that, zlint could
stop inferring "subordinate" from a failed verification: IsSubCA(c) is true for
every self-issued CA whose signature could not be checked, and a third state
(self-issued, signature unverifiable) would keep those out of both profiles
rather than silently placing them in one. NOTE
