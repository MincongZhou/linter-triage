#!/bin/bash
# ZT-029 — three e_sub_cert_* lints have no subscriber guard and hold CA
# certificates to the Subscriber Certificate profile, while the e_sub_ca_*
# siblings beside them guard correctly. lints/cabf_br/, the pairs side by
# side: lint_sub_cert_crl_distribution_points_does_not_contain_url.go return
# util.IsExtInCert(c, util.CrlDistOID)
# lint_sub_ca_crl_distribution_points_does_not_contain_url.go return
# util.IsSubCA(c) && util.IsExtInCert(c, util.CrlDistOID)
# lint_sub_cert_crl_distribution_points_marked_critical.go return
# util.IsExtInCert(c, util.CrlDistOID)
# lint_sub_ca_crl_distribution_points_marked_critical.go return
# util.IsSubCA(c) && util.IsExtInCert(c, util.CrlDistOID)
# lint_sub_cert_eku_server_auth_client_auth_missing.go return c.ExtKeyUsage
# != nil Two of anything is a design; the guarded halves of those two pairs
# settle what the design is. Each unguarded lint carries "Subscriber
# certificate" in its own Name and Description and cites BRs 7.1.2.3, which
# is headed "Subscriber Certificate". The clause next door states different
# requirements for the same extension: 7.1.2.2 Subordinate CA Certificate b.
# cRLDistributionPoints This extension MUST be present and MUST NOT be
# marked critical. It MUST contain the HTTP URL of the CA's CRL service. g.
# extKeyUsage (optional/required) For Cross Certificates that share a
# Subject Distinguished Name and Subject Public Key with a Root Certificate
# ... this extension MAY be present. 7.1.2.3 Subscriber Certificate b.
# cRLDistributionPoints This extension MAY be present. If present, it MUST
# NOT be marked critical, and it MUST contain the HTTP URL of the CA's CRL
# service. -- BR 1.8.7, the version in force for most of the window these
# lints cover. Same extension, different presence rule, and a wholly
# different extKeyUsage requirement. This is the shape already recorded as
# ZT-001 for the six subjectAltName name-type lints; these three are the
# rest of it. All three case files are CA certificates: two real trust-store
# intermediates and one of zlint's own fixtures, named subCAWcrlDistCrit.pem
# for the sub-CA lint it was written for. ./positive/ZT-029-repro.sh
# /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
N=e_sub_cert_crl_distribution_points_does_not_contain_url,e_sub_ca_crl_distribution_points_does_not_contain_url,e_sub_cert_crl_distribution_points_marked_critical,e_sub_ca_crl_distribution_points_marked_critical,e_sub_cert_eku_server_auth_client_auth_missing

for f in positive/ZT-029-subordinate-ca-crldp-no-http.pem \
         positive/ZT-029-subordinate-ca-crldp-critical.pem \
         positive/ZT-029-subordinate-ca-eku-timestamping.pem ; do
  echo "== $f"
  openssl x509 -in "$D/$f" -noout -subject -ext basicConstraints 2>/dev/null \
    | sed 's/^/   /'
  "$Z" -includeNames="$N" "$D/$f" || echo "   REFUSED"
  echo
done

cat <<'NOTE'

Observed (zlint v3.7.1-20-g1007b1d5), on three CA certificates:

intermediate-097538169f89d9ec, cRLDistributionPoints with no http URI
e_sub_cert_crl_distribution_points_does_not_contain_url error
      e_sub_ca_crl_distribution_points_does_not_contain_url     error   (correct)

subCAWcrlDistCrit.pem, cRLDistributionPoints marked critical
e_sub_cert_crl_distribution_points_marked_critical error
      e_sub_ca_crl_distribution_points_marked_critical          error   (correct)

intermediate-5b8f7eaf75d18d67, extKeyUsage = id-kp-timeStamping
e_sub_cert_eku_server_auth_client_auth_missing error

Correct: NA from every e_sub_cert_* lint above. The first two certificates are
already reported by the correctly scoped sibling, so the substance is not lost;
the third is reported by nothing else, and would need either a sub-CA sibling
or nothing at all, since BR 7.1.2.2(g) does not require either authentication
purpose of a subordinate CA.

Reach, over the 21,778 corpus certificates zlint read:

lint fires on CA certs e_sub_cert_crl_distribution_points_does_not_contain_url
90 25 e_sub_cert_eku_server_auth_client_auth_missing 15 6
e_sub_cert_crl_distribution_points_marked_critical 10 5

36 CA certificates in all. The two CRLDP siblings fire 23 and 5 times, and
every one of those firings is on a certificate the unguarded lint has already
reported -- so 28 of the 36 are duplicates and 8 are findings no correctly
scoped lint makes.

Two of the 25 CA certificates under the first lint are root CAs, which
util.IsSubCA excludes, so adding the guard would leave those two unreported.
BR 7.1.2.11.2 does state the http requirement unconditionally of any
cRLDistributionPoints that is present, so the right end state is a guard plus
a third lint, or one lint scoped to every certificate and named for the clause
rather than for one profile.

Fix: `util.IsSubscriberCert(c) &&` in front of each of the three CheckApplies
bodies. util.IsSubscriberCert already exists and 33 lints in lints/ use it.
NOTE
