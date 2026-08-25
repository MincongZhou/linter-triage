#!/bin/bash
# ZT-027 — BR-sourced lints are scoped by a serverAuth proxy, so BR
# requirements binding a non-serverAuth certificate go unchecked.
# lint/base.go, before any lint's own CheckApplies runs: if
# !l.OverrideFrameworkFilter { if l.Source == CABFBaselineRequirements &&
# !util.IsServerAuthCert(cert) { return &LintResult{Status: NA} } ... BR
# 7.1.2.8 profiles the delegated OCSP Responder certificate, and its
# subjectPublicKeyInfo row points at 7.1.3.1 (key sizes) and its signature
# row at 7.1.3.2. A delegated responder asserts id-kp-OCSPSigning and not
# serverAuth, so util.IsServerAuthCert is false and every BR lint without
# the override returns NA on it. Exactly four lints set
# OverrideFrameworkFilter, all four about OCSP responders; the key-size and
# signature-algorithm lints do not. Both certificates here are FABRICATED
# and self-signed. Same 1024-bit RSA subject key, same subject, same
# validity (2024-01-01 to 2024-03-01), same CABF DV policy OID. They differ
# in one field: extKeyUsage. ./positive/ZT-027-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"

echo "== EKU = id-kp-OCSPSigning, RSA 1024"
"$Z" -includeNames=e_rsa_mod_less_than_2048_bits,e_mp_modulus_must_be_2048_bits_or_more \
     "$D/positive/ZT-027-ocsp-responder-rsa1024.pem" || echo FAILED
echo
echo "== EKU = id-kp-serverAuth, the same 1024-bit key"
"$Z" -includeNames=e_rsa_mod_less_than_2048_bits,e_mp_modulus_must_be_2048_bits_or_more \
     "$D/negative/ZT-027-control-serverauth-rsa1024.pem" || echo FAILED

cat <<'NOTE'

Observed (zlint v3.7.1-20-g1007b1d5):

  OCSPSigning  {"e_mp_modulus_must_be_2048_bits_or_more":{"result":"error"},
                "e_rsa_mod_less_than_2048_bits":{"result":"NA"}}
  serverAuth   {"e_mp_modulus_must_be_2048_bits_or_more":{"result":"error"},
                "e_rsa_mod_less_than_2048_bits":{"result":"error"}}

The Mozilla-sourced lint fires on both, which is how you know the certificate
really is non-conformant and that only the BR filter is hiding it.

Running the lints directly against the same certificate, bypassing the
framework, shows what the filter suppresses on a real delegated responder
(, EKU = OCSPSigning only):

IsServerAuthCert = false CABF_BR certificate lints registered : 166 suppressed
by the pre-flight filter alone : 6 e_rsa_mod_less_than_2048_bits body would
have said pass e_signature_algorithm_not_supported body would have said pass
e_no_underscores_before_1_6_2 body would have said pass
e_dnsname_hyphen_in_sld, e_dnsname_underscore_in_sld,
w_dnsname_underscore_in_trd

The four lints that do set OverrideFrameworkFilter are
e_ocsp_cert_cdp_forbidden, e_ocsp_cert_cp_forbidden, e_ocsp_cert_invalid_ku
and e_ocsp_id_pkix_ocsp_nocheck_ext_not_included_server_auth — every one of
them a lint whose entire population is the population the filter excludes.
They had to opt out individually to see their own subject matter.

Note what the filter is *right* about: on an S/MIME or code-signing
certificate it correctly suppresses subscriber-TLS lints that would otherwise
be false positives, which is why most BR lints must not carry the override.
The defect is not the filter's existence but that its predicate is a proxy —
IsServerAuthCert is true for anyEKU, for no EKU at all, and for any BR policy
OID — and nothing enumerates the BR requirements that bind a certificate the
proxy rejects.

A correct tool would scope BR lints by the role the document profiles
(subscriber, subordinate CA, root CA, OCSP responder) so that a BR-wide
requirement such as 7.1.3.1 key sizes applies to every profile the BRs define,
and a profile-specific requirement applies only to its own. NOTE
