#!/bin/bash
# CT-003 — cablint has no Baseline Requirements floor. Every BR check runs
# on every certificate whatever its notBefore, so pre-2012 issuance is
# reported against requirements that did not exist when it was signed.
# ./positive/CT-003-repro.sh /path/to/certlint-checkout
set -u
CL="${1:-.}"
D="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
openssl x509 -in "$D/positive/CT-003-pre-br-root.pem" -outform der -out "$T/c.der" 2>/dev/null

echo "== a root CA in the Mozilla trust store, issued 2001-01-10"
openssl x509 -in "$D/positive/CT-003-pre-br-root.pem" -noout -subject -startdate 2>/dev/null | sed 's/^/   /'
echo
echo "== cablint"
(cd "$CL" && ruby -Ilib -Iext bin/cablint "$T/c.der" 2>/dev/null | sed 's/\t.*//' | grep '^E:') | sed 's/^/   /'

cat <<'NOTE'

Observed: three errors against a certificate signed eleven years and five
months before the Baseline Requirements took effect.

Correct: one.

E: basicConstraints must be critical in CA certificates LEGITIMATE. RFC 5280
4.2.1.9 requires it, and RFC 2459 4.2.1.10 required it in 1999. This one binds
in 2001 and is not a BR question at all.

E: CA certificates must set keyUsage extension as critical BR 7.1.2.10.7. RFC
5280 4.2.1.3 makes criticality a SHOULD for a CA, so in 2001 this is at most a
warning -- and cablint separately emits
        exactly that warning, "W: Extension should be critical for KeyUsage",
        on the same certificate and the same run.

E: DistributionPoints other than URIs are not permitted BR 7.1.2.11.2. No such
requirement existed in 2001.

MECHANISM

cablint.rb:77, `def self.lint(der)`, has no notBefore test. It returns early
only for a fatal parse error or an OpenSSL exception; there is no branch that
declines to apply the Baseline Requirements to a certificate issued before
they existed.

The constant is present and correct and is used ONCE:

    cablint.rb:25   BR_1_0_EFFECTIVE = Time.utc(2012, 7, 1)
    cablint.rb:504  elsif c.not_before >= BR_1_0_EFFECTIVE

Line 504 is the last rung of the validity-period ladder. Every other Baseline
Requirements check in the file runs undated. cablint is not date-unaware -- it
gates on NO_SHA1, BR_1_7_1_EFFECTIVE, BR_2_0_0_EFFECTIVE, SHORTLIVED_7 and
SHORTLIVED_10 elsewhere -- so this is a missing floor rather than a missing
capability.

REACH (the corpus, 21,802 certificates, every one run through bin/cablint)

  2,613  certificates issued before 2012-07-01
  1,286  of them draw at least one cablint E:  (49.2%)

The commonest, and note how closely they track the textbook case -- a CA
certificate reported for keyUsage criticality, basicConstraints criticality
and a small RSA modulus, none of which was required when it was issued:

578 CA certificates must include an HTTP URL of the OCSP responder 477 CA
certificates must set keyUsage extension as critical 176 CRL Distribution
Point must be an HTTP URL 121 RSA subject key modulus must be at least 2048
bits 101 CA certificates must include countryName in subject 74
basicConstraints must be critical in CA certificates 67 Unless Short-lived, BR
certificates must include the HTTP URL of ... 67 CA certificates must include
organizationName in subject 67 BR certificates must include
certificatePolicies 65 BR certificates must have subject alternative names
extension

The 74 basicConstraints findings are the legitimate ones; RFC 5280 backs them.
The rest are Baseline Requirements text applied outside its own era.

WHY IT MATTERS AT SCALE

Certificate Transparency carries certificates issued over more than twenty
years, and root and intermediate certificates are routinely fifteen to twenty
years old. A monitor running cablint over CT will report roughly half of that
historical population as misissuance. That buries the findings that are real.

FIX

An early return in `self.lint`, before the CAB checks:

    if c.not_before < BR_1_0_EFFECTIVE
      messages << 'I: Issued before the Baseline Requirements; CAB checks skipped'
return messages end

RELATED

CT-002 is the same class one era later: the CDP scheme rule of BR 2.0 applied
to pre-2.0 certificates. That entry notes cablint "already implements the
pre-2.0 reading; only the gate between them is missing". CT-003 is the floor
under all of it. NOTE
