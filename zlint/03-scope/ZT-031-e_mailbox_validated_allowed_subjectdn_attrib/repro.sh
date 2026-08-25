#!/bin/bash
# ZT-031 -- e_mailbox_validated_allowed_subjectdn_attributes applies a
# subscriber-only subject table to CA certificates. Citation: S/MIME BRs:
# 7.1.4.2.3 CheckApplies: return util.IsMailboxValidatedCertificate(c)
# S/MIME BR s7.1.4.2 is headed "Subject information - subscriber
# certificates", and s7.1.4.2.3 is one of its four profile tables. The 30 it
# adds are all CA:TRUE. Certificate: a real Subordinate CA from the CCADB
# trust store, KIR S.A.'s SZAFIR Trusted CA9 SMIME, asserting four reserved
# S/MIME identifiers including 2.23.140.1.5.1.2. Control: one of zlint's own
# subscriber fixtures for the same clause, which both lints report and which
# is not in dispute.
set -u
Z=${ZLINT:-$HOME/.local/bin/zlint}
D=$(dirname "$0")
A=e_mailbox_validated_allowed_subjectdn_attributes
B=e_mailbox_validated_enforce_subject_field_restrictions
echo "zlint: $($Z -version 2>&1 | head -1)"
echo

for f in "$D/positive/ZT-031-mailbox-validated-subordinate-ca.pem" \
         "$D/negative/ZT-031-control-subscriber.pem"; do
    echo "--- $(basename "$f")"
    echo "subject : $(openssl x509 -in "$f" -noout -subject | sed 's/^subject=//')"
    echo "CA      : $(openssl x509 -in "$f" -noout -ext basicConstraints 2>/dev/null | tail -n +2 | tr -d ' \n')"
    for l in $A $B; do
        r=$($Z -includeNames="$l" "$f" 2>/dev/null | tr -d '{}"' )
        echo "    $r"
    done
    echo
done

echo "observed: the subordinate CA is reported by the lint without the role"
echo "          test and passed by the lint with it -- one clause, two"
echo "          answers, and the section addresses subscriber certificates"
echo "correct : NA on a CA certificate, as the sibling already answers"
echo "fix     : CheckApplies -> IsMailboxValidatedCertificate(c) &&"
echo "          util.IsSubscriberCert(c), matching the sibling. The wider"
echo "          question is whether the two lints should both exist: they"
echo "          cite one section and read one table."
