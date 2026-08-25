#!/bin/bash
# PT-028 — pkilint reports a permission as an ERROR. Microsoft Trusted Root
# Program Requirements 3.A.5 states two obligations in one sentence: issuing
# CA certificates MUST carry revocation information, and end-entity
# certificates MAY. pkilint's validator quotes the *permissive* sentence in
# its own docstring and then declares it at ERROR severity. Needs pkilint
# installed. Run: ./positive/PT-028-repro.sh # uses python3
# ./positive/PT-028-repro.sh /path/to/python # the interpreter pkilint is in
# $1 is the INTERPRETER, not a source directory -- that is the contract
# run.sh invokes every reproduction under (`bash "$s" "$PY"`). The source
# tree is then derived from that interpreter, so the two can never disagree.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
PY="${1:-python3}"

SRC=$($PY -c 'import pkilint,pathlib;print(pathlib.Path(pkilint.__file__).parent)' 2>/dev/null) \
  || { echo "pkilint not importable by $PY"; exit 2; }
echo "pkilint source: $SRC"
$PY -c 'import importlib.metadata as m;print("version:", m.version("pkilint"))' 2>/dev/null

echo
echo "== the validator, as pkilint ships it =="
sed -n '/class EndEntityRevocationInformationPresenceValidator/,/pdu_class=rfc5280.Extensions/p' \
    "$SRC/msft/msft_extension.py"

cat <<'NOTE'

== what the cited clause says ==

Microsoft Trusted Root Program Requirements, "3. Program Technical
Requirements" -> "A. Root Requirements" -> item 5, in full:

  "All issuing CA certificates MUST contain either a CDP extension with a
valid CRL and/or an AIA extension to an OCSP responder. An end-entity
certificate MAY contain either an AIA extension with a valid OCSP URL and/or a
CDP extension pointing to a valid HTTP endpoint containing the CRL. If an AIA
extension with a valid OCSP URL is NOT included, then the
   resulting CRL File SHOULD be <10MB."

  (emphasis added; the document spells them "must", "may" and "should".)

The sentence pkilint's docstring quotes is the second one. Its normative verb
is "may". pkilint declares the finding ERROR.

observed msft.end_entity.revocation_information_absent at ERROR on an
end-entity certificate carrying neither extension correct no finding: 3.A.5
permits an end-entity certificate to carry revocation information and does not
require it

The document's own cross-reference fixes the numbering: the Note under
"C. Revocation Requirements" cites "section 3.C.3", so this clause is 3.A.5.
pkilint's docstring already cites 3.A.5 correctly.

NOTE

echo "== reproduction: a certificate with neither AIA nor cRLDistributionPoints =="
openssl x509 -in "$HERE/positive/PT-028-cert.pem" -noout -subject 2>/dev/null
echo "   extensions present:"
openssl x509 -in "$HERE/positive/PT-028-cert.pem" -noout -text 2>/dev/null \
  | grep -E "^            X509v3" | sed 's/^ */     /'

echo
echo "   pkilint, typed as pkilint's own detection types it:"
$PY -m pkilint.bin.lint_cabf_serverauth_cert lint -t EV-FINAL-CERTIFICATE \
    "$HERE/positive/PT-028-cert.pem" 2>&1 | grep -A1 "RevocationInformationPresenceValidator" | sed 's/^/     /'

cat <<'NOTE'

The control is on the same line of output. `cabf.serverauth.subscriber.
revocation_information_absent` is the CA/Browser Forum requirement, which is
mandatory, and reporting it is correct. The Microsoft code adds a second ERROR
for a clause that permits what it reports.

== the requirement that IS mandatory has no check here ==

The first sentence -- issuing CA certificates MUST carry a CDP or an AIA -- is
not implemented by any msft.* code. It is largely subsumed: a certificate can
breach it only by carrying neither extension, which for a subordinate CA is
already cabf.serverauth.ca.crl_distribution_points_extension_absent.

== a fix ==

Either drop the validator, or keep it and demote the finding to a severity
that matches the clause -- pkilint already has INFO and NOTICE, and a
"revocation information absent" notice on an end-entity certificate is a
defensible thing to say. What it cannot be is an ERROR, because no requirement
is broken. NOTE
