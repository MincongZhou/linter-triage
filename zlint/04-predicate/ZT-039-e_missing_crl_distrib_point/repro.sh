#!/bin/bash
# ZT-039 — e_missing_crl_distrib_point tests for an OCSP *URI* where BR
# 7.1.2.11.2 conditions the requirement on an id-ad-ocsp *accessMethod*.
# lints/cabf_br/lint_missing_crl_distrib_point.go: func (l
# *MissingCRLDistribPoint) Execute(c *x509.Certificate) *lint.LintResult {
# if len(c.CRLDistributionPoints) == 0 && len(c.OCSPServer) == 0 { return
# &lint.LintResult{Status: lint.Error, ...} c.OCSPServer is not "the
# id-ad-ocsp access descriptions". zcrypto discards an access description
# before it looks at the method, on the general-name tag alone —
# x509/x509.go, parsing the AIA extension: for _, v := range aia { //
# GeneralName: uniformResourceIdentifier [6] IA5String if v.Location.Tag !=
# 6 { continue } if v.Method.Equal(oidAuthorityInfoAccessOcsp) {
# out.OCSPServer = append(out.OCSPServer, string(v.Location.Bytes)) So a
# certificate that does include an authorityInformationAccess extension with
# an id-ad-ocsp accessMethod, but writes the accessLocation as something
# other than a uniformResourceIdentifier, arrives at Execute with an empty
# OCSPServer and is faulted for a missing cRLDistributionPoints extension.
# BR 7.1.2.11.2 states the condition on the accessMethod, not on the
# location: The CRL Distribution Points extension MUST be present in: -
# Subordinate CA Certificates; and - Subscriber Certificates that 1) do not
# qualify as "Short-lived Subscriber Certificates" and 2) do not include an
# Authority Information Access extension with an `id-ad-ocsp` accessMethod.
# and §7.1.2.11.1's note repeats it: "whether or not the CRL Distribution
# Points extension must be present depends on 1) whether the Certificate
# includes an Authority Information Access extension with an `id-ad-ocsp`
# accessMethod and 2) the Certificate's validity period". The lint's own
# Description paraphrases this as "lacking an OCSP pointer", which is looser
# than the clause it cites. The malformed accessLocation is a real defect
# and zlint already reports it, correctly and separately, as
# e_aia_must_contain_permitted_access_method ("invalid GeneralName with tag
# 2 in an accessLocation"). Nothing here disputes that finding. What ZT-039
# is about is the *second* error: a demand for an extension the cited clause
# does not require, which a CA acting on the report would satisfy by adding
# a cRLDistributionPoints extension while leaving the actual defect in
# place. The two inputs below differ in one thing: the general-name type of
# the id-ad-ocsp accessLocation. Neither carries cRLDistributionPoints.
# ./positive/ZT-039-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
N=e_missing_crl_distrib_point

for f in positive/ZT-039-ocsp-accesslocation-dnsname.pem \
         negative/ZT-039-control-ocsp-accesslocation-uri.pem ; do
  echo "== $f"
  openssl x509 -in "$D/$f" -noout -ext authorityInfoAccess 2>/dev/null \
    | sed 's/^/   /'
  echo "   cRLDistributionPoints: $(openssl x509 -in "$D/$f" -noout -ext crlDistributionPoints 2>/dev/null | grep -c 'URI' || true) URIs"
  "$Z" -includeNames="$N" "$D/$f" || echo "   REFUSED"
  echo
done

cat <<'NOTE'

Observed (zlint v3.7.1-20-g1007b1d5):

id-ad-ocsp with a dNSName accessLocation, no cRLDistributionPoints
e_missing_crl_distrib_point error
      e_aia_must_contain_permitted_access_method   error   (correct)

the same certificate with a uniformResourceIdentifier accessLocation
e_missing_crl_distrib_point pass

Correct: pass on both. Both certificates include an authorityInformationAccess
extension with an id-ad-ocsp accessMethod, which is the condition BR
7.1.2.11.2 states, so neither is required to carry cRLDistributionPoints.

The shape is rare in issued certificates precisely because it is already
prohibited by BR 7.1.2.7.7, which requires the accessLocation to be a
uniformResourceIdentifier with an http scheme. The defect is nonetheless a
second, wrong finding on every certificate that has the first one.

Provenance: fabricated. Built by python cryptography 43.0.0 as an ordinary OV
subscriber certificate — notBefore 2024-06-01, so after SC-63's 2024-03-15; 90
days of validity, so not a Short-lived Subscriber Certificate under either the
ten-day or the seven-day threshold; serverAuth, CA:FALSE, no
cRLDistributionPoints — differing only in the accessLocation general-name type.
On the control every zlint error is absent; on the case the only errors are the
two above.

Fix: test the accessMethod the clause names rather than the URI list. zlint
has util.AiaOID and no constant for id-ad-ocsp itself, so the lint-local fix
is to
unmarshal c.ExtensionsMap[util.AiaOID.String()] and look for the method OID
regardless of accessLocation type -- lint_ext_cannot_be_empty_seq.go already
reads raw extensions that way. The fix one level down is for zcrypto to record
the id-ad-ocsp access descriptions it currently drops on the tag test, which
would also let e_aia_ocsp_must_have_http_only see them. NOTE
