#!/bin/bash
# ZT-044 — e_signature_algorithm_not_supported escalates RSASSA-PSS from the warning its own table assigns to an error, whenever zcrypto declines to map the PSS parameters.  lints/cabf_br/lint_signature_algorithm_not_supported.go:  warnSigAlgs = map[x509.SignatureAlgorithm]bool{ x509.SHA256WithRSAPSS: true, x509.SHA384WithRSAPSS: true, x509.SHA512WithRSAPSS: true, } ... status := lint.Error if passSigAlgs[sigAlg] { status = lint.Pass } else if warnSigAlgs[sigAlg] { status = lint.Warn }  The severity comes from `c.SignatureAlgorithm`, which is zcrypto's mapping rather than the algorithm OID. zcrypto/x509/x509.go, GetSignatureAlgorithmFromAI:  if !bytes.Equal(params.Hash.Parameters.FullBytes, asn1.NullBytes) || !params.MGF.Algorithm.Equal(oidMGF1) || !mgf1HashFunc.Algorithm.Equal(params.Hash.Algorithm) || !bytes.Equal(mgf1HashFunc.Parameters.FullBytes, asn1.NullBytes) || params.TrailerField != 1 { return UnknownSignatureAlgorithm }  So an id-RSASSA-PSS AlgorithmIdentifier whose hash parameters are absent rather than an explicit NULL, or whose salt length differs from the digest size, arrives at Execute as UnknownSignatureAlgorithm. Neither map holds it, `status` keeps its initial lint.Error, and a certificate signed with an algorithm BR 7.1.3.2 lists is reported as one the profile does not support. The parameter encoding is a real defect and zlint reports it, correctly and separately, as e_mp_rsassa-pss_parameters_encoding_in_signature_algorithm_correct -- "3 presentations are allowed but got the unsupported 303d06...". Nothing here disputes that. What ZT-044 is about is the second finding, which names the algorithm rather than its encoding, and which a CA acting on the report would satisfy by abandoning RSASSA-PSS altogether. The two inputs are both zlint's own testdata and differ only in whether the hash AlgorithmIdentifiers inside the PSS parameters carry their NULL.  ./positive/ZT-044-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
N=e_signature_algorithm_not_supported,e_mp_rsassa-pss_parameters_encoding_in_signature_algorithm_correct

for f in positive/ZT-044-rsassa-pss-hash-params-absent.pem \
         negative/ZT-044-control-rsassa-pss-canonical.pem ; do
  echo "== $f"
  openssl x509 -in "$D/$f" -noout -text 2>/dev/null \
    | grep -i -A4 "signature algorithm" | head -6 | sed 's/^/   /'
  "$Z" -includeNames="$N" "$D/$f" || echo "   REFUSED"
  echo
done

cat <<'NOTE'

Observed (zlint v3.7.1-20-g1007b1d5):

rsassapssWithSHA256EmptyHashParams.pem e_signature_algorithm_not_supported
error e_mp_rsassa-pss_parameters_encoding_in_signature_algorithm_correct
                                                              error   (correct)

rsassapssWithSHA256.pem, the same algorithm canonically encoded
e_signature_algorithm_not_supported warn

Correct: warn on both, which is what the lint's own table says about
SHA256WithRSAPSS. The control demonstrates the mechanism -- the two files
carry the same algorithm OID and differ only in the PSS parameter encoding,
and the severity moves two levels.

BR 7.1.3.2 lists RSASSA-PSS with SHA-256, SHA-384 and SHA-512 among the
algorithms a CA SHALL use, with a byte-for-byte encoding for each. The lint's
own comment records the reading: "The BRs do not forbid the use of RSA-PSS as a
signature scheme in certificates but it is not broadly supported by
user-agents", which is why it is a warning.

The other 62 firings are 50 md5WithRSAEncryption, 11 md2WithRSAEncryption and
one
GOST R 34.11-94 (1.2.643.2.2.3), and are correct.

This corrects an aside in ZT-050, which says of that same root that "zlint
separately and correctly reports e_public_key_type_not_allowed and
e_signature_algorithm_not_supported". The first of those is right -- BR 7.1.3.1
says the CA "SHALL NOT use a different algorithm, such as the id-RSASSA-PSS
(OID: 1.2.840.113549.1.1.10) algorithm identifier, to indicate an RSA key",
which is about the subjectPublicKeyInfo. The second is this defect: the
signature algorithm is in the table.

Fix: read the severity from the algorithm identifier rather than from zcrypto's
mapping -- test `c.SignatureAlgorithmOID.Equal(oidSignatureRSAPSS)` before
falling through to Error. Independently, zcrypto could keep the three PSS
constants for parameter sets it recognises and return a fourth for
"id-RSASSA-PSS, parameters not one of the three", so a caller can tell an
unrecognised algorithm from an unrecognised encoding of a recognised one. NOTE
