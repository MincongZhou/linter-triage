#!/bin/bash
# ZT-067 - w_subject_common_name_included applies the Baseline Requirements' "NOT RECOMMENDED" to EV certificates, whose subject the Baseline Requirements hand to the EV Guidelines, where the word is still "Deprecated (Discouraged, but not prohibited)". The lint cites BRs 7.1.2.7.1, which enumerates the four Subscriber Certificate types. Three of the four carry a commonName row reading NOT RECOMMENDED. The fourth does not:  7.1.2.7.5 Extended Validation | subject | See Guidelines for the Issuance and Management of Extended |         | Validation Certificates, Section 7.1.4.2. |  and EVG 7.1.4.2.2, in the current text, reads:  Certificate Field: subject:commonName (OID: 2.5.4.3) Required/Optional: Deprecated (Discouraged, but not prohibited)  which is the wording the *other* lint of this pair, n_subject_common_name_included, was written for and reports as a notice. So an EV certificate issued after SC62 is told its commonName is NOT RECOMMENDED by a table that does not cover it, and no lint states the word its governing document actually uses. zlint is not missing the EV-ness: its own EV lints run on this certificate and pass.  ./positive/ZT-067-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
SUBJECT="$D/positive/ZT-067-ev-subscriber-with-common-name.pem"           # EV
CONTROL="$D/negative/ZT-067-control-ov-subscriber-with-common-name.pem"   # OV

echo "== the two certificates"
echo "   both are subscriber certificates issued after SC62 took effect on"
echo "   2023-09-15, and both carry a commonName. They differ in their type."
for f in "$SUBJECT" "$CONTROL"; do
  printf '   %-52s ' "$(basename "$f")"
  openssl x509 -in "$f" -noout -startdate | sed 's/notBefore=//'
done

echo
echo "== which reserved policy identifier each asserts"
for f in "$SUBJECT" "$CONTROL"; do
  printf '   %-52s ' "$(basename "$f")"
  openssl x509 -in "$f" -noout -text \
    | grep -oE '2\.23\.140\.1\.(1|2\.[123])' | sort -u | tr '\n' ' '
  echo
done
echo "   2.23.140.1.1 is Extended Validation; 2.23.140.1.2.2 is Organization"
echo "   Validated. The first is judged by EVG 7.1.4.2, the second by the"
echo "   Organization Validated subject table in BRs 7.1.2.7.4."

echo
echo "== zlint's own EV lints, which decide EV-ness the same way"
for lint in e_ev_business_category_missing e_ev_serial_number_missing \
            e_ev_organization_name_missing e_ev_country_name_missing; do
  a=$("$Z" -includeNames "$lint" "$SUBJECT" | sed -E 's/.*"result":"([a-zA-Z]+)".*/\1/')
  b=$("$Z" -includeNames "$lint" "$CONTROL" | sed -E 's/.*"result":"([a-zA-Z]+)".*/\1/')
  printf '   %-46s EV=%-5s OV=%s\n' "$lint" "$a" "$b"
done
echo "   pass against NA: zlint knows which of the two is an EV certificate."

echo
echo "== and the pair of commonName lints, which do not"
for lint in n_subject_common_name_included w_subject_common_name_included; do
  a=$("$Z" -includeNames "$lint" "$SUBJECT" | sed -E 's/.*"result":"([a-zA-Z]+)".*/\1/')
  b=$("$Z" -includeNames "$lint" "$CONTROL" | sed -E 's/.*"result":"([a-zA-Z]+)".*/\1/')
  printf '   %-46s EV=%-5s OV=%s\n' "$lint" "$a" "$b"
done

echo
echo "observed  an EV certificate draws w_subject_common_name_included, whose"
echo "          description reads \"commonName is NOT RECOMMENDED\" and whose"
echo "          citation is a section that hands the EV subject to another"
echo "          document. Nothing reports the word that document uses."
echo "correct   NA on an EV certificate -- CheckApplies should exclude one,"
echo "          the same test the cabf_ev lints above already make -- and a"
echo "          notice from a lint citing EVG 7.1.4.2.2 in its place."
