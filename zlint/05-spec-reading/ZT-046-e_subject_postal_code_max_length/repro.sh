#!/bin/bash
# ZT-046 — e_subject_postal_code_max_length bounds id-at-postalCode with a constant belonging to a different, unrelated ASN.1 type.  lint_subject_postal_code_max_length.go:  ub-postal-code-length INTEGER ::= 16     // its own comment Citation: "RFC 5280: A.1" if utf8.RuneCountInString(j) > 16 { Error }  reading c.Subject.PostalCode, which is the Subject DN attribute id-at-postalCode, 2.5.4.17. RFC 5280 Appendix A.1 does define ub-postal-code-length = 16, but it bounds  PostalCode ::= CHOICE { numeric-code   NumericString (SIZE (1..ub-postal-code-length)), printable-code PrintableString (SIZE (1..ub-postal-code-length)) }  which is the X.400 postal-delivery OR-address type -- it sits among ub-pds-name-length and ub-pds-parameter-length in the 1988-syntax module. It has nothing to do with the Subject DN attribute. RFC 5280 defines no X520PostalCode at all, so the RFC supplies no bound for 2.5.4.17. The governing bound is ITU-T X.520's ub-postal-code = 40, which is what the Baseline Requirements' own § 7.1.4.2 table cites:  | postalCode | 2.5.4.17 | X.520 | ... | 40 |  The sibling e_subject_street_address_max_length cites X.520 directly and gets 128 right, so this is a slip in one lint rather than a house reading. Case: a real certificate from Mozilla bug 1771482 whose postalCode is 25 characters -- conformant at 40, reported at 16.
set -u
Z=${ZLINT:-$HOME/.local/bin/zlint}
D=$(dirname "$0")
echo "zlint: $($Z -version 2>&1 | head -1)"
echo
echo "-- observed --"
$Z -includeNames=e_subject_postal_code_max_length "$D/positive/ZT-046-postalcode-19-chars.der" 2>/dev/null
openssl x509 -in "$D/positive/ZT-046-postalcode-19-chars.der" -inform DER -noout -subject 2>/dev/null \
  | tr ',' '\n' | grep -i postal | sed 's/^ */  /'
python3 - "$D/positive/ZT-046-postalcode-19-chars.der" <<'PY'
import sys, warnings
warnings.filterwarnings("ignore")
from cryptography import x509 from cryptography.x509.oid import NameOID
c = x509.load_der_x509_certificate(open(sys.argv[1], "rb").read())
for a in c.subject.get_attributes_for_oid(NameOID.POSTAL_CODE):
    print(f"  postalCode is {len(a.value)} characters: bound is 40, not 16")
PY
echo
echo "observed: error   (25 characters faulted against a 16-character bound)"
echo "correct : pass    (X.520 ub-postal-code is 40)"
echo "fix     : bound id-at-postalCode at 40 per ITU-T X.520, not at"
echo "          RFC 5280 A.1's ub-postal-code-length, which bounds an"
echo "          X.400 OR-address type"
