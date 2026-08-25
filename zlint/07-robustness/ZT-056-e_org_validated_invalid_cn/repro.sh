#!/bin/bash
# ZT-056 — e_org_validated_invalid_cn panics on an organization-validated S/MIME certificate that carries no organizationName, and returns Fatal. Description: "In OV S/MIME certs, the Subject CN must either contain an email address or match organizatioName" Citation:    CABF SMIME BRs §7.1.4.2.2  Execute reads Organization[0] without testing the slice:  if isEmail(c.Subject.CommonName) || c.Subject.CommonName == c.Subject.Organization[0] { return &lint.LintResult{Status: lint.Pass} }  isEmail("") is false, so a certificate with no commonName falls through to the index — and if it also has no organizationName, that index is out of range. lint.CertificateLint.Execute recovers per-lint and records  Fatal: 'e_org_validated_invalid_cn' panicked. Error: runtime error: index out of range [0] with length 0  so nothing else in the run is lost; this lint alone renders no verdict on the certificate. Both halves are also wrong on their own terms. §7.1.4.2.2(a) opens "If present, this attribute SHALL contain one of the following values", and the §7.1.4.2.4 table states commonName as MAY — so an absent commonName is conformant and should be NA rather than anything else. Certificates: zlint's own fixtures, unmodified.
set -u
Z=${ZLINT:-$HOME/.local/bin/zlint}
D=$(dirname "$0")
L=e_org_validated_invalid_cn
echo "zlint: $($Z -version 2>&1 | head -1)"
echo

for c in positive/ZT-056-ov-no-organization-name negative/ZT-056-control-ov-with-common-name; do
  f="$D/$c.pem"
  echo "$c"
  echo "    subject: $(openssl x509 -in "$f" -noout -subject 2>/dev/null | sed 's/^subject=//')"
  $Z -includeNames=$L "$f" 2>/dev/null | tr ',' '\n' | sed 's/^/    /'
  echo
done

echo "observed: Fatal, from an index out of range, on a certificate whose"
echo "          commonName is absent and therefore conformant"
echo "correct : NA — §7.1.4.2.2(a) binds the attribute only \"If present\""
echo "fix     : already written on the upstream branch origin/pr1069_followup,"
echo "          unmerged as of master 1007b1d5:"
echo "              CheckApplies: ... && c.Subject.CommonName != \"\""
echo "              Execute:      ... || (len(c.Subject.Organization) > 0 &&"
echo "                                    c.Subject.CommonName == c.Subject.Organization[0])"
