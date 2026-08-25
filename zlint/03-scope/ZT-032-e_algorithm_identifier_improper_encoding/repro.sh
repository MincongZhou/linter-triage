#!/bin/bash
# ZT-032 -- e_algorithm_identifier_improper_encoding has no scope test, so
# it condemns S/MIME certificates under a TLS Baseline Requirements
# citation.
# lints/cabf_br/lint_subject_public_key_info_improper_algorithm_object_identifier_encoding.go
# holds the four encodings BR s7.1.3.1 permits -- RSA, P-256, P-384, P-521
# -- and its CheckApplies is: func (l *algorithmObjectIdentifierEncoding)
# CheckApplies(c *x509.Certificate) bool { // always check if the public key
# is one of the four explicitly specified encodings return true } The
# CA/Browser Forum S/MIME Baseline Requirements state their OWN s7.1.3.1
# with a different list. Since v1.0.0 it has included id-Ed25519 and
# id-Ed448; v1.0.11 added ML-DSA and ML-KEM. So an Ed25519 S/MIME
# certificate conforms to the document that governs it and is reported by
# this lint anyway, citing "BRs: 7.1.3.1" -- a clause that does not bind it.
# The control is inside zlint itself. On the SAME certificate and the SAME
# field, e_invalid_legacy_spki_algoid -- zlint's own S/MIME reading of
# s7.1.3.1 -- returns pass. Two lints, one field, opposite answers, and only
# one of them is reading the document that applies. Certificate: zlint's own
# ed25519_legacy_digital_signature_ku.pem, which asserts a reserved S/MIME
# policy identifier. It carries other defects, all irrelevant here: the
# claim is the contradiction between two lints about one field, which no
# other finding touches. Control: zlint's own dsaCert.pem -- a DSA key in a
# TLS certificate, outside the four encodings and inside the document. The
# lint reports it, which proves the byte comparison works and is not what is
# at fault.
set -u
Z=${ZLINT:-$HOME/.local/bin/zlint}
D=$(dirname "$0")
echo "zlint: $($Z -version 2>&1 | head -1)"
echo

echo "--- positive/ZT-032-ed25519-smime.pem (S/MIME, id-Ed25519)"
echo "policy  : $(openssl x509 -in "$D/positive/ZT-032-ed25519-smime.pem" -noout -text 2>/dev/null \
    | grep -m1 -A1 'Certificate Policies' | grep -o '2\.23\.140[0-9.]*')"
echo "key     : $(openssl x509 -in "$D/positive/ZT-032-ed25519-smime.pem" -noout -text 2>/dev/null \
    | grep -m1 'Public Key Algorithm' | sed 's/.*Algorithm: //')"
$Z -includeNames=e_algorithm_identifier_improper_encoding,e_invalid_legacy_spki_algoid \
   "$D/positive/ZT-032-ed25519-smime.pem" 2>/dev/null | tr ',' '\n' | sed 's/^/    /'
echo

echo "--- negative/ZT-032-control-dsa-tls.pem (TLS, DSA)"
echo "key     : $(openssl x509 -in "$D/negative/ZT-032-control-dsa-tls.pem" -noout -text 2>/dev/null \
    | grep -m1 'Public Key Algorithm' | sed 's/.*Algorithm: //')"
$Z -includeNames=e_algorithm_identifier_improper_encoding \
   "$D/negative/ZT-032-control-dsa-tls.pem" 2>/dev/null | tr ',' '\n' | sed 's/^/    /'
echo

echo "observed: on the S/MIME certificate, e_algorithm_identifier_improper_encoding"
echo "          reports error while e_invalid_legacy_spki_algoid reports pass --"
echo "          the same field, judged by two documents, and the one that does"
echo "          not govern the certificate is the one that condemns it."
echo "          On the control the lint reports error, correctly: the byte"
echo "          comparison works and scope is the whole defect."
echo "correct : NA on the S/MIME certificate. BR s1.1 addresses certificates"
echo "          for TLS server authentication; S/MIME BR s7.1.3.1 states its"
echo "          own permitted list and zlint already implements it in"
echo "          e_invalid_spki_algoid and e_invalid_legacy_spki_algoid."
echo "fix     : give CheckApplies a scope test. zlint has util.IsServerAuthCert"
echo "          and the S/MIME predicates in util already, and 157 of the 172"
echo "          lint files on the cabf_br shelf carry a conditional"
echo "          CheckApplies -- so a scope test is the house convention there"
echo "          and its absence here is a slip rather than a design."
echo
echo "Reach on this corpus is 4 of 21,778, all zlint's own S/MIME fixtures --"
echo "but the population is every Ed25519, Ed448, ML-DSA and ML-KEM S/MIME"
echo "certificate, which the S/MIME BR has permitted since 2023-09-01 and"
echo "which post-quantum migration will make ordinary."
