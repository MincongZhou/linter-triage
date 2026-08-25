#!/bin/bash
# ZT-014 — two root keyUsage lints cite the Baseline Requirements and are
# dated util.RFC2459Date, thirteen and a half years before the Baseline
# Requirements existed.
# lints/cabf_br/lint_root_ca_key_usage_must_be_critical.go and
# lints/cabf_br/lint_root_ca_key_usage_present.go: Citation: "BRs: 7.1.2.1",
# Source: lint.CABFBaselineRequirements, EffectiveDate: util.RFC2459Date, //
# 1999-01-01 BR 7.1.2.1(b) reads "This extension MUST be present and MUST be
# marked critical", and has since BR 1.1.6; the Requirements themselves take
# effect 2012-07-01, util.CABEffectiveDate, which 75 other lints in cabf_br/
# use. lint/base.go states what the field means: "Lints automatically
# returns NE for all certificates where CheckApplies() is true but with
# NotBefore < EffectiveDate." The criticality lint is the substantive half.
# RFC 5280 4.2.1.3 — and RFC 2459 before it — says only "Conforming CAs
# SHOULD mark this extension as critical". The MUST is the CA/Browser
# Forum's and dates from 2012, so every firing on an earlier root converts
# an RFC SHOULD into a BR error thirteen years early. The presence lint is
# the citation half: RFC 2459 4.2.1.3 does require the extension of a
# certificate whose key validates certificate signatures, so the 1999 date
# suits the requirement while the Source and Citation name a document that
# cannot supply it. Its sibling lint_ca_key_usage_missing.go cites both
# documents and dates itself util.RFC3280Date accordingly. The first two
# inputs are real trust-store roots with a non-critical keyUsage, differing
# in notBefore. ./positive/ZT-014-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
N=e_root_ca_key_usage_must_be_critical,e_root_ca_key_usage_present,e_ca_key_usage_missing

for f in positive/ZT-014-root-2003-keyusage-not-critical.pem \
         negative/ZT-014-control-root-2016-keyusage-not-critical.pem \
         positive/ZT-014-root-2002-no-keyusage.pem ; do
  echo "== $f"
  echo "   $(openssl x509 -in "$D/$f" -noout -dates 2>/dev/null | tr '\n' ' ')"
  echo "   $(openssl x509 -in "$D/$f" -noout -subject 2>/dev/null | cut -c1-100)"
  "$Z" -includeNames="$N" "$D/$f" || echo "   REFUSED"
  echo
done

cat <<'NOTE'

Observed (zlint v3.7.1-20-g1007b1d5):

POSTArCA, notBefore 2003-02-07, keyUsage present and not critical
e_root_ca_key_usage_must_be_critical error e_root_ca_key_usage_present pass

TrustCor ECA-1, notBefore 2016-01-15, keyUsage present and not critical
e_root_ca_key_usage_must_be_critical error e_root_ca_key_usage_present pass

Colegio de Registradores root, notBefore 2002-04-30, no keyUsage at all
e_root_ca_key_usage_present error e_ca_key_usage_missing error

Reach, over the 21,778 corpus certificates zlint read:

  e_root_ca_key_usage_must_be_critical   93 firings, 73 on roots issued before
      2012-07-01 — 1999 (13), 2000 (4), 2001 (9), 2002 (5), 2003 (4), 2004 (6),
      2005 (7), 2006 (6), 2007 (6), 2008 (2), 2009 (2), 2010 (2), 2011 (5),
      2012 (2 before the date). 68 of the 73 are trust-store roots.
e_root_ca_key_usage_present 36 firings, 29 on roots issued before 2012-07-01,
23 of them trust-store roots.

The rest are worth a line each:

e_dnsname_hyphen_in_sld, e_dnsname_underscore_in_sld and
w_dnsname_underscore_in_trd cite the BRs and are dated util.RFC5280Date
  (2008-05-01); together they fault one corpus certificate before 2012.
  w_sub_ca_name_constraints_not_critical is dated util.CABV102Date
  (2012-06-08), the ballot rather than the effective date — the same shape as
  against Citation "RFC 5280: 4.2.1.6", where the Source rather than the date
  is the mismatch.

Lints whose EffectiveDate is util.ZeroDate are excluded throughout: zlint
treats a zero date as no lower bound at all rather than as a date, so those
make no dating claim to contradict.

Fix: EffectiveDate: util.CABEffectiveDate on both root keyUsage lints. For the
presence lint the alternative is to keep the date and add RFC 5280 4.2.1.3 to
the Citation, as lint_ca_key_usage_missing.go already does. NOTE
