#!/bin/bash
# ZT-015 — e_root_ca_key_usage_must_be_critical applies a CA/Browser Forum
# Baseline Requirement to certificates issued thirteen years before the
# Forum published one. Two lints, one source, one requirement, two dates:
# lints/cabf_br/lint_ca_key_usage_not_critical.go Name:
# "e_ca_key_usage_not_critical", Source: lint.CABFBaselineRequirements,
# EffectiveDate: util.CABEffectiveDate, // 2012-07-01
# lints/cabf_br/lint_root_ca_key_usage_must_be_critical.go Name:
# "e_root_ca_key_usage_must_be_critical", Source:
# lint.CABFBaselineRequirements, EffectiveDate: util.RFC2459Date, //
# 1999-01-01 util/time.go: CABEffectiveDate = time.Date(2012, time.July, 1,
# ...) RFC2459Date = time.Date(1999, time.January, 1, ...) The general lint
# carries the Forum's own effective date. The root-specific one carries the
# date of RFC 2459 — a document published by the IETF three years before the
# CA/Browser Forum existed, and which states no such requirement. Nothing in
# the Baseline Requirements binds a certificate issued in 1999.
# ./positive/ZT-015-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
N=e_root_ca_key_usage_must_be_critical,e_ca_key_usage_not_critical

for f in positive/ZT-015-root-in-window.pem negative/ZT-015-control-root-post-br.pem ; do
  echo "== $f"
  openssl x509 -in "$D/$f" -noout -subject -startdate 2>/dev/null | sed 's/^/   /'
  openssl x509 -in "$D/$f" -noout -text 2>/dev/null \
    | grep -A1 "X509v3 Key Usage" | head -2 | sed 's/^/   /'
  "$Z" -includeNames="$N" "$D/$f" || echo "   REFUSED"
  echo
done

cat <<'NOTE'

Observed (zlint v3.7.1-20-g1007b1d5):

positive/ZT-015-root-in-window.pem — self-signed CA, notBefore 1999-03-18,
keyUsage present and not critical

e_ca_key_usage_not_critical NE e_root_ca_key_usage_must_be_critical error

  negative/ZT-015-control-root-post-br.pem — the same shape, notBefore 2014-03-05

e_ca_key_usage_not_critical error e_root_ca_key_usage_must_be_critical error

Correct: NE from both on the first. The control holds every other property
fixed and moves only the issuance date, so the date is demonstrably the whole
of the difference — and on the first certificate zlint states both answers at
once about one requirement.

The Baseline Requirements' own Effective Date is 2012-07-01, which is what
util.CABEffectiveDate is for and what the sibling lint uses. BR 1.1.0's
Appendix B states the criticality requirement identically in the Root CA and
Subordinate CA profiles and scopes the appendix to certificates generated
after its date; no earlier Forum document states it at all, and RFC 2459
§4.2.1.3 makes the extension's criticality a SHOULD rather than a MUST.

notBefore falls between 1999-01-01 and 2012-07-01; the three-certificate
difference is zlint's own root test, which is not DN equality alone.

These are overwhelmingly trust-store roots — the population least able to act
on the report, since a root cannot be reissued to fix an extension without
being redistributed.

Fix: EffectiveDate: util.CABEffectiveDate, matching the sibling lint and the
Source both already declare. If the intent was to state a requirement that
predates the Forum, the Source is what is wrong rather than the date, and RFC
2459 will not support it either — its keyUsage criticality is a SHOULD. NOTE
