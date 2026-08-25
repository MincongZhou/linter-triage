#!/bin/bash
# ZT-047 — e_subject_contains_noninformational_value faults an
# organizationalUnitName in the ten weeks when the Baseline Requirements
# excepted that attribute by name. The lint's own block comment quotes the
# clause it enforces: BRs: 7.1.4.2.2 Other Subject Attributes With the
# exception of the subject:organizationalUnitName (OU) attribute, optional
# attributes, when present within the subject field, MUST contain
# information that has been verified by the CA. Metadata such as '.', '-',
# and ' ' (i.e. space) characters, and/or any other indication that the
# value is absent, incomplete, or not applicable, SHALL NOT be used. That
# paragraph is BR 1.0 § 9.2.6, word for word -- the only version of the
# document that ever carried the OU exception. BR 1.0 was effective
# 2012-07-01, which is exactly util.CABEffectiveDate, so the lint's start
# date is right. What is wrong is that it enforces the paragraph against the
# one attribute the paragraph excludes, for as long as BR 1.0 was the
# version in force. BR 1.1.0, effective 2012-09-14, split the section in two
# -- § 9.2.6 for OU, § 9.2.7 for everything else -- and the exception phrase
# does not survive the split. From 2012-09-14 the lint is correct about OU.
# Three real certificates from the same issuance line, differing in date:
# 2012-06-19 before the BRs bind NE 2012-08-16 BR 1.0 in force error <- the
# defect 2012-09-18 BR 1.1.0 in force error correct All three carry OU = "-"
# and no other metadata-only attribute, so the date is the only thing that
# differs in what the lint has to judge.
set -u
Z=${ZLINT:-$HOME/.local/bin/zlint}
D=$(dirname "$0")
echo "zlint: $($Z -version 2>&1 | head -1)"
echo

for c in negative/ZT-047-control-2012-06-19-before-the-brs \
         positive/ZT-047-ou-hyphen-2012-08-16 \
         negative/ZT-047-control-2012-09-18-after-br-1-1-0; do
  f="$D/$c.der"
  openssl x509 -inform DER -in "$f" -out "$D/.zl042.pem" 2>/dev/null
  printf '%-46s %s\n' \
    "$(openssl x509 -in "$D/.zl042.pem" -noout -startdate | cut -d= -f2)" \
    "$($Z -includeNames=e_subject_contains_noninformational_value "$D/.zl042.pem" 2>/dev/null)"
  openssl x509 -in "$D/.zl042.pem" -noout -subject | tr ',' '\n' | grep -i "OU *=" | sed 's/^ */    subject /'
done
rm -f "$D/.zl042.pem"

echo
echo "observed: error on the 2012-08-16 certificate"
echo "correct : pass   — BR 1.0 § 9.2.6 excepts subject:organizationalUnitName"
echo "                   from the sentence this lint enforces, and BR 1.0 was"
echo "                   the version in force until 2012-09-14"
echo "fix     : skip organizationalUnitName when notBefore is earlier than"
echo "          2012-09-14, the effective date of BR 1.1.0. The other attributes"
echo "          carry the requirement from 2012-07-01 and need no change."
echo
echo "note    : the Forum's own archive page lists no version before 1.1, so a"
echo "          search of the published series reports this clause as beginning"
echo "          2012-09-14 and the lint as ten weeks early. It is not: the BR 1.0"
echo "          PDF is at cabforum.org/uploads/Baseline_Requirements_V1.pdf, and"
echo "          it carries the clause. This project reached the opposite, wrong"
echo "          conclusion first from exactly that gap."
