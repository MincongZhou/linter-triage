#!/bin/bash
# ZT-020 -- e_cs_rsa_key_size is dated 22 months before the RSA-3072
# deadline. Citation: CABF CS BRs 6.1.5.2 EffectiveDate:
# util.CABF_CS_BRs_1_2_Date = 2019-08-13 The current text of s6.1.5.2 states
# the requirement flatly: If the Key is RSA, then the modulus MUST be at
# least 3072 bits in length. It did not always. CS BR v1.2, the first
# edition, states it in Appendix A as a table with two dated columns: Code
# Signing Certificates issued Code Signing Certificates issued on prior to
# January 1, 2021 or after January 1, 2021
# ------------------------------------------------------------------ Minimum
# RSA modulus size 2048 3072 and ballot CSC-4, v2.1, 7 Nov 2020 -- titled
# "Move deadline for transition to RSA-3072 and SHA-2 timestamp tokens" --
# moves the column boundary to 1 June 2021. v2.4's Relevant Dates table
# gives 2021-06-01 against Appendix A(1). The undated sentence arrives with
# v2.4, after the transition closed. So RSA-2048 was conformant in a code
# signing certificate for 22 months of the window this lint judges, and the
# lint reports it as an error. Certificate: a real Sectigo/USERTrust code
# signing certificate issued 19 March 2021, RSA-2048, asserting
# 2.23.140.1.4.1 -- eleven weeks inside the deadline. It is in , where a
# finding is a false positive. Control: zlint's own fixture for this lint,
# issued 2024, where RSA-2048 is a real defect and the error is correct.
set -u
Z=${ZLINT:-$HOME/.local/bin/zlint}
D=$(dirname "$0")
L=e_cs_rsa_key_size
echo "zlint: $($Z -version 2>&1 | head -1)"
echo

for f in "$D/positive/ZT-020-code-signing-rsa2048-2021-03.pem" \
         "$D/negative/ZT-020-control-after-deadline.pem"; do
    echo "--- $(basename "$f")"
    echo "subject : $(openssl x509 -in "$f" -noout -subject | sed 's/^subject=//' | cut -c1-72)"
    echo "issued  : $(openssl x509 -in "$f" -noout -startdate | sed 's/^notBefore=//')"
    echo "key     : RSA-$(openssl x509 -in "$f" -noout -text | grep -m1 -oE 'Public-Key: \([0-9]+' | grep -oE '[0-9]+')"
    $Z -includeNames=$L "$f" 2>/dev/null | tr ',' '\n' | sed 's/^/    /'
    echo
done

echo "observed: error on both -- the same verdict for a certificate issued"
echo "          inside the transition window and one issued three years after"
echo "correct : NE on the first. On 19 March 2021 the Requirements in force"
echo "          were v2.2, whose Appendix A gave RSA-2048 until 1 June 2021."
echo "fix     : a CABF_CS_CSC_4_Date = 2021-06-01 as this lint's EffectiveDate."
