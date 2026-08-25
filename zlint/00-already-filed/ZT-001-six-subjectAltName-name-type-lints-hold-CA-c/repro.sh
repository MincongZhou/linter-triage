#!/bin/bash
# ZT-001 — the six subjectAltName name-type lints apply a Subscriber
# Certificate clause to CA certificates.
# lints/cabf_br/lint_ext_san_directory_name_present.go, and its five
# siblings: func (l *SANDirName) CheckApplies(c *x509.Certificate) bool {
# return util.IsExtInCert(c, util.SubjectAlternateNameOID) } The guard is
# "this certificate has a subjectAltName", of any kind, held against the
# Contents sentence of BRs 7.1.4.2.1. lint_ext_san_missing.go cites that
# same clause — "BRs: 7.1.4.2.1" — for the Required/Optional row of the same
# table, describes it as "Subscriber certificates MUST contain the Subject
# Alternate Name extension", and guards with `!util.IsCACert(c)`. One
# clause, one table row, two scopes inside one package. The document agrees
# with the narrower reading. 7.1.4.2 is headed "Subject Information —
# Subscriber Certificates" from BR 1.4.8; 7.1.4.3 profiles Root and
# Subordinate CA subject information and states no subjectAltName name-type
# table at all; in BR 2.0.0 the clause is 7.1.2.7.12 "Subscriber Certificate
# Subject Alternative Name". A CA certificate's subjectAltName falls under
# the CA extension tables' "Any other extension: NOT RECOMMENDED", never
# under a MUST NOT on a name type. The two inputs below differ in
# basicConstraints. Both carry a directoryName in the subjectAltName.
# ./positive/ZT-001-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
N=e_ext_san_directory_name_present,e_ext_san_rfc822_name_present,e_ext_san_uniform_resource_identifier_present,e_ext_san_other_name_present,e_ext_san_edi_party_name_present,e_ext_san_registered_id_present,e_ext_san_missing

for f in positive/ZT-001-subordinate-ca-san-directoryname.pem \
         negative/ZT-001-control-subscriber-san-directoryname.pem ; do
  echo "== $f"
  echo "   subject: $(openssl x509 -in "$D/$f" -noout -subject 2>/dev/null)"
  openssl x509 -in "$D/$f" -noout -ext basicConstraints,subjectAltName 2>/dev/null \
    | sed 's/^/   /'
  "$Z" -includeNames="$N" "$D/$f" || echo "   REFUSED"
  echo
done

cat <<'NOTE'

Observed (zlint v3.7.1-20-g1007b1d5):

  eSignTrust Government Certification Authority (G03), CA:TRUE pathlen:0,
subjectAltName holding one directoryName, notBefore 2017-01-01
e_ext_san_directory_name_present error
      e_ext_san_missing                  NA      <- same clause, scoped

A Spanish port authority end-entity certificate, CA:FALSE, subjectAltName
holding a dNSName and a directoryName, notBefore 2016-08-28
e_ext_san_directory_name_present error e_ext_san_missing pass

Correct: NA on the first, error on the second. The requirement the six lints
cite binds Subscriber Certificates, and the lint beside them that cites it
says so.

Per lint, firings and how many of them are CA certificates:

e_ext_san_directory_name_present 444 411 e_ext_san_rfc822_name_present 438 385
e_ext_san_uniform_resource_identifier_present 53 30
e_ext_san_other_name_present 11 4 e_ext_san_edi_party_name_present 3 1
e_ext_san_registered_id_present 4 0

The scope is deliberate rather than an oversight, which is worth stating
plainly: the directoryName lint's own fixtures are
SANDirectoryNameBeginning.pem
and SANDirectoryNameEnd.pem, both CA:TRUE and both expected `lint.Error`, and
its negative fixture is named SANCaGood.pem. Narrowing CheckApplies therefore
requires new fixtures, and the two existing positives become NA. That is the
work the fix costs, not an argument against it — the clause the lint cites has
never bound those certificates.

Fix: open each of the six CheckApplies with util.IsSubscriberCert(c), matching
lint_ext_san_missing.go on the same clause, and reissue the fixtures as
end-entity certificates. NOTE
