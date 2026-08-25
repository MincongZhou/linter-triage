#!/bin/bash
# ZT-058 - e_org_validated_invalid_cn panics on an OV S/MIME certificate with no organizationName.  func (l *OrgValidatedInvalidCN) Execute(c *x509.Certificate) *lint.LintResult { if isEmail(c.Subject.CommonName) || c.Subject.CommonName == c.Subject.Organization[0] {  Organization is a []string and is indexed without a length check. Go's short-circuit spares a certificate whose commonName is an email address; every other OV S/MIME certificate with an empty Organization panics. CertificateLint.Execute recovers it and returns Fatal, so nothing else in the run is lost -- but the lint reaches no verdict, and Fatal sits at or above the error floor for anything counting findings. The population is the one that matters most: S/MIME BR 7.1.4.2.2 requires organizationName in an OV certificate, so the lint crashes precisely on the certificates that breach the requirement next door.  ./positive/ZT-058-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
N=e_org_validated_invalid_cn

echo "== an OV S/MIME certificate whose subject has no organizationName"
openssl x509 -in "$D/positive/ZT-058-ov-smime-no-organization.pem" -noout -subject 2>/dev/null
openssl x509 -in "$D/positive/ZT-058-ov-smime-no-organization.pem" -noout -text 2>/dev/null \
  | sed -n '/Certificate Policies/,+1p' | tail -1
"$Z" -includeNames "$N" "$D/positive/ZT-058-ov-smime-no-organization.pem"

echo
echo "== control: an OV S/MIME certificate that does carry one, same lint"
openssl x509 -in "$D/negative/ZT-058-control-reaches-a-verdict.pem" -noout -subject 2>/dev/null
"$Z" -includeNames "$N" "$D/negative/ZT-058-control-reaches-a-verdict.pem"

echo
echo "observed  fatal, from a runtime panic indexing Organization[0]."
echo "correct   the lint should reach a verdict. An OV certificate with no"
echo "          organizationName cannot have a commonName matching it, so"
echo "          error is the answer once the index is guarded."
