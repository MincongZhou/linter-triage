#!/bin/bash
# ZT-004 — e_ev_organization_id_missing applies an EV Guidelines Subscriber
# Certificate requirement to Subordinate CA certificates.
# lints/cabf_ev/lint_ev_orgid_missing.go registers no role predicate: the
# CheckApplies is satisfied by any certificate asserting an EV policy and
# naming subject:organizationIdentifier, whether it is a Subscriber
# Certificate or a CA. EV Guidelines section 7.1.2 is the Subscriber
# Certificate profile. EV CA certificates are profiled separately in
# 7.1.4.3, which states no such condition. The question was put to the
# CA/Browser Forum by an EU conformity assessment body and answered by the
# Chair on 2026-02-09: "The requirements for the presence and contents of
# extensions in EV CA certificates are indicated in section 7.1.4.3. The
# requirements for extensions in section 7.1.2 (where the OrgId extension is
# listed alongside the SAN extension) are applicable only to Subscriber
# Certificates." A Certificate Problem Report advancing the opposite
# reading, against the certificate below, was closed as invalid on that
# basis -- Mozilla Bugzilla 2056663, July 2026. ./positive/ZT-004-repro.sh
# /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
F="$D/positive/ZT-004-subordinate-ca-orgid.pem"

echo "== the certificate the Problem Report was about"
openssl x509 -in "$F" -noout -subject 2>/dev/null | sed 's/^/   /'
openssl x509 -in "$F" -noout -text 2>/dev/null \
  | grep -A1 "X509v3 Basic Constraints" | head -2 | sed 's/^/   /'
echo
"$Z" -includeNames=e_ev_organization_id_missing "$F" || echo "   REFUSED"

cat <<'NOTE'

Observed (zlint v3.7.1-20-g1007b1d5):

  e_ev_organization_id_missing   error
      "subject:organizationIdentifier field is present in an EV certificate
       but the CA/Browser Forum Organization Identifier Field Extension is
       missing"

Correct: NA.

They are predominantly EU qualified-hierarchy intermediates whose
subjects carry an organizationIdentifier under ETSI EN 319 412-1 (forms such
as NTRNL-30237459 and VATES-Q2826004J) and which assert an EV policy because
they may *issue* EV, not because they are EV certificates. The corpus holds 749
CA certificates naming an organizationIdentifier without the extension; the 26
are those also asserting an EV policy, which is this lint's own gate.

The population is the one least able to act on the report. A subordinate CA
cannot be reissued to add an extension without being redistributed, and the
requirement it would be satisfying does not exist.

Fix: gate CheckApplies on the certificate being a Subscriber Certificate, as
the lints implementing the rest of section 7.1.2 do. Independently, the EV
Guidelines would benefit from the profile cleanup the Baseline Requirements
received in Ballot SC-62; the incident report proposes exactly that.
NOTE
