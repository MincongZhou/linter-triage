#!/bin/bash
# ZT-011 — e_excessively backdated is switched off by the field it polices.
# The lint reports a notBefore more than 48 hours older than an embedded
# SCT. It carries EffectiveDate: util.SC62EffectiveDate (2023-09-15), and
# the framework decides applicability from c.NotBefore — the same field the
# lint exists to distrust. Backdate far enough and the lint goes away. Both
# certificates are zlint's own fixtures, copied unmodified from v3/testdata
# (via ). They differ only in notBefore:
# positive/ZT-011-backdated-before-sc62.pem notBefore 2023-06-12, SCT
# +133.5h negative/ZT-011-control-backdated-after-sc62.pem notBefore
# 2026-02-11, SCT +72.0h ./positive/ZT-011-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
L='e_excessively backdated'

echo "== notBefore 2023-06-12, an SCT 133.5 hours later (before SC-62)"
"$Z" -includeNames="$L" "$D/positive/ZT-011-backdated-before-sc62.pem" || echo FAILED
echo
echo "== notBefore 2026-02-11, an SCT 72.0 hours later (after SC-62)"
"$Z" -includeNames="$L" "$D/negative/ZT-011-control-backdated-after-sc62.pem" || echo FAILED

cat <<'NOTE'

Observed (zlint v3.7.1-20-g1007b1d5):

  before SC-62   {"e_excessively backdated":{"result":"NE"}}
  after  SC-62   {"e_excessively backdated":{"result":"error", ...}}

Both certificates are backdated by the lint's own definition. Only the one
whose falsified notBefore lands after 2023-09-15 is reported.

Upstream's own test states the behaviour as intended —
lints/cabf_br/lint_excessively_backdated_test.go:

    desc: "Certificate with SCTs and a bad notBefore, issued before Effective Date"
    path: "excbakdat_sct1_old1_eff0.pem"
    want: lint.NE

The framework's applicability test is
lint/base.go:  checkEffective(l.EffectiveDate, l.IneffectiveDate, c.NotBefore)

A correct tool would decide applicability for this lint from an issuance-time
signal the certificate cannot restate — the earliest embedded SCT timestamp is
already parsed by the lint body — or set OverrideFrameworkFilter and gate on
that. Any lint whose subject is the trustworthiness of notBefore cannot use
notBefore as its own scope test. NOTE
