#!/bin/bash
# ZT-049 — e_crl_auth_key_id_only_contains_keyid cannot see the field it forbids: authorityCertIssuer is GeneralNames, a constructed [1], and the lint decodes tag 1 into []byte, which encoding/asn1 will not populate from a constructed element. The field reads back nil and the certificate the lint exists to catch passes.  lints/cabf_br/lint_crl_auth_key_id_only_contains_keyid.go:  type authKey struct { KeyIdentifier             []byte   `asn1:"optional,tag:0"` AuthorityCertIssuer       []byte   `asn1:"optional,tag:1"` AuthorityCertSerialNumber *big.Int `asn1:"optional,tag:2"` } ... if authKey.AuthorityCertIssuer != nil || authKey.AuthorityCertSerialNumber != nil { return &lint.LintResult{Status: lint.Error, ...} }  This is a separate registry from the certificate lints: LintRevocationList runs registry.RevocationListLints(), reached only by -format der against a .crl file (zlint's own format sniff only recognises .der/.pem suffixes).  ./positive/ZT-049-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
N=e_crl_auth_key_id_only_contains_keyid

echo "== real-world CRL, AuthorityKeyIdentifier carries authorityCertIssuer + authorityCertSerialNumber"
echo "   positive/ZT-049-crl-constructed-authority-cert-issuer.crl (, sha256 0e59cbb70fca...)"
openssl asn1parse -inform der -in "$D/positive/ZT-049-crl-constructed-authority-cert-issuer.crl" 2>/dev/null \
  | grep -A1 'Authority Key' | head -2
"$Z" -format der -includeNames="$N" "$D/positive/ZT-049-crl-constructed-authority-cert-issuer.crl" || echo "   REFUSED"

echo
echo "== control: zlint's own test fixture for the same lint"
echo "   negative/ZT-049-control-zlint-fixture-primitive-issuer.pem (v3/testdata/crlWithAuthKeyIDContainsAuthorityCertIssuer.pem, unmodified)"
"$Z" -includeNames="$N" "$D/negative/ZT-049-control-zlint-fixture-primitive-issuer.pem" || echo "   REFUSED"

cat <<'NOTE'

Observed (zlint v3.7.1-20-g1007b1d5):

  real-world CRL (constructed [1])   pass
  zlint's own fixture (primitive [1]) error

Correct: error on the real-world CRL. BRs 7.2.2 forbids authorityCertIssuer
and authorityCertSerialNumber in a CRL's AuthorityKeyIdentifier; this CRL
carries both.

The mechanism, read from the bytes (openssl asn1parse, both files):

  zlint's fixture     81 0a 8208726f6f742e646e73          tag [1], PRIMITIVE, len 10
  real-world CRL       a1 69 a467 30 65 31 0b ...          tag [1], CONSTRUCTED, len 105

GeneralNames is, by its own ASN.1 definition, a SEQUENCE — always constructed.
encoding/asn1 will not unmarshal a constructed element into a []byte through
an implicit tag: the field is left nil rather than erroring, so the guard
`AuthorityCertIssuer != nil` never sees it. The trailing
authorityCertSerialNumber then goes unconsumed too — Go's asn1 leaves it for
the next optional field, which is exactly what it is, so that field is also
read correctly in isolation, but only the issuer's absence is what the guard
tests, and that test has already gone false.

zlint's own test (TestAuthKeyIDOnlyContainsKeyID, case
"crlWithAuthKeyIDContainsAuthorityCertIssuer") asserts lint.Error and the
binary agrees — the test is not wrong given its fixture. The fixture is wrong:
BRs 7.2.2 gives authorityCertIssuer no encoding of its own, and
GeneralNames (RFC 5280 §4.2.1.6) has none but the constructed one. A
primitive [1] is not valid DER for the field the lint claims to be testing;
it is a different malformation (a truncated OCTET STRING-shaped [1]) that
happens to also make the guard fire, for a reason the lint's own comment does
not describe. Against DER encoded the only way the ASN.1 module allows, the
lint is blind to every certificate carrying the property it forbids.

pkilint corroborates the field is genuinely present on this class of CRL: run
against full-0d34dd618012.crl (also in , not shipped here)
it reports at node path
certificateList.tbsCertList.crlExtensions.0.extnValue.authorityKeyIdentifier.authorityCertSerialNumber.

Corpus (2026-08-15, 286 CRLs): 9 carry authorityCertIssuer and
authorityCertSerialNumber together, 8 with thisUpdate inside the lint's
effective window (CABFBRs_2_0_1_Date). zlint returns pass on all 8.

Fix: decode tag 1 into an asn1.RawValue, or into a properly typed
GeneralNames, so a constructed element matches instead of being skipped. NOTE
