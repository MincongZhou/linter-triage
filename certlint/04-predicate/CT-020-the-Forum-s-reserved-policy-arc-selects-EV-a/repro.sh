#!/bin/bash
# CT-020 — cablint reads the CA/Browser Forum reserved policy arc to detect
# EV and not to exclude. A certificate asserting an S/MIME Baseline
# Requirements policy identifier with no extendedKeyUsage is typed as a TLS
# server certificate from its keyUsage alone, and judged against the TLS
# profile. Certificates: fabricated, differing only in whether
# extendedKeyUsage is present. Recipe at the end.
set -u
CL="${1:-.}"
D="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

run() {
  openssl x509 -in "$1" -outform der -out "$T/c.der" 2>/dev/null
  (cd "$CL" && ruby -Ilib -Iext bin/cablint "$T/c.der" 2>/dev/null) | sed 's/\t.*//'
}

echo "== SUBJECT: policy 2.23.140.1.5.1.2 (S/MIME BR), rfc822Name SAN, NO extendedKeyUsage"
openssl x509 -in "$D/positive/CT-020-smime-policy-no-eku.pem" -noout -ext certificatePolicies,keyUsage,subjectAltName 2>/dev/null \
  | grep -v "^X509v3\|^$" | sed 's/^/      /'
run "$D/positive/CT-020-smime-policy-no-eku.pem" | sed 's/^/   /'

echo
echo "== CONTROL: the same certificate with an emailProtection extendedKeyUsage"
openssl x509 -in "$D/negative/CT-020-control-smime-policy-with-eku.pem" -noout -ext extendedKeyUsage 2>/dev/null \
  | grep -v "^X509v3\|^$" | sed 's/^/      /'
run "$D/negative/CT-020-control-smime-policy-with-eku.pem" | sed 's/^/   /'

cat <<'NOTE'

Observed: five Baseline Requirements errors against an S/MIME certificate --
          including "BR certificates must not contain rfc822Name type
          alternative name", which reports the name form the S/MIME Baseline
Requirements REQUIRE of it, and a 398-day validity limit that does not apply
to S/MIME certificates at all.
Correct:  "I: No certificate type identified", or an S/MIME verdict. The
certificate asserts a CA/Browser Forum policy identifier that names a
different Forum document.

The two certificates differ in one extension. The policy identifier is
identical in both, and it is not what decides the answer.

THE MECHANISM

cablint guesses the certificate type at cablint.rb:345-450, under its own
comment "Use EKUs, Subject attribute types, and Policies to guess the cert
type". It reads the reserved arc there:

    cablint.rb:359   if certpolicies.value.include?('2.23.140.1.')
    cablint.rb:360     if ...include?('2.23.140.1.1') || ...include?('2.23.140.1.3')
                          is_ev = true

So the arc IS read -- to decide EV, and only that. Nothing consults it again.
Sixty lines later, for a certificate with no extendedKeyUsage:

    cablint.rb:408   if eku.empty? && !ku.nil?
    cablint.rb:410     if ku.include?('Digital Signature') ||
                          ku.include?('Key Encipherment')
    cablint.rb:411       eku << 'tmp-serverauth-usable'

and 'tmp-serverauth-usable' is one of the five ways line 428 recognises an
in-scope certificate. A digitalSignature + keyEncipherment keyUsage is the
ordinary shape of an S/MIME signing and encryption certificate, so the
inference fires on exactly the population it should not.

The comment above line 422 states the reasoning honestly -- "If the certificate
has neither keyUsage nor extendedKeyUsage, it is unrestricted so it can be used
for anything" -- and that is true of RFC 5280. It is not true of a certificate
whose CA has asserted 2.23.140.1.5.x, which is the Forum's own identifier for
"this is governed by the S/MIME Baseline Requirements".

REACH

Over the corpus (21,802 certificates): **391 assert an S/MIME BR policy identifier
and 320 a Code Signing BR one.** Of those, cablint types 65 as TLS server
certificates, and 63 of them wrongly:

     61  S/MIME arc, no extendedKeyUsage      -> typed from keyUsage alone
      2  Code Signing arc, no extendedKeyUsage -> the same
      2  S/MIME arc, EKU names serverAuth      -> correctly typed; a certificate
                                                  asserting serverAuth IS in scope

The 61 draw 63 x "must include authorityInformationAccess", 63 x "must have
subject alternative names extension", 52 x "must be 398 days in validity or
less" and 17 x "commonNames must be from SAN entries", among others. Everything
with an emailProtection EKU is correctly left alone, which is why the figure
is 61 and not 391 -- the defect needs the EKU to be absent.

FIX

At the type guess, let the reserved arc exclude as well as select:

2.23.140.1.5.x S/MIME Baseline Requirements 2.23.140.1.4.x Code Signing
Baseline Requirements

A certificate asserting either, and not also asserting serverAuth, is not a
TLS server certificate whatever its keyUsage says. The value is already parsed
three lines from where the decision is made.

HOW THE CERTIFICATES WERE MADE

Fabricated, so the pair differs in exactly one extension. A throwaway CA signs
two end-entity certificates: CN=person@cl007.example, an rfc822Name SAN,
keyUsage digitalSignature + keyEncipherment, certificatePolicies
2.23.140.1.5.1.2, validity 2024-01-01 to 2026-12-01. One carries an
emailProtection extendedKeyUsage and the other carries none. The issuing CA is
beside them as positive/CT-020-issuing-ca.pem. Neither chains to any trust
store.

`E: BR certificates must have subject alternative names extension` against
NOTE
