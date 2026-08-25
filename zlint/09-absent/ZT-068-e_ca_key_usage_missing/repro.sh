#!/bin/bash
# ZT-068 - no lint reports a subscriber certificate with no keyUsage. BR
# 7.1.2.7.6 gives keyUsage as SHOULD, critical. On a serverAuth subscriber
# carrying AKI, SKI and EKU but no keyUsage, all 25 key-usage lints return
# NA. The adjacent names do not cover it: e_ca_key_usage_missing and
# e_root_ca_key_usage_present are CA-scoped, e_sub_cert_key_usage_*_bit_set
# are conditional on the bit being present, e_cabf_ecc_allowed_key_usages is
# gated on util.HasKeyUsageOID, and e_key_usage_presence /
# e_cs_key_usage_required come from the S/MIME and Code Signing BRs. No
# w_sub_cert_key_usage_missing exists. Absence was established by
# enumerating all 431 registered lints. Certificate: zlint's own fixture
# ecdsaP256AbsentKU.pem, unmodified. ./positive/ZT-068-repro.sh
# /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"

echo "== every lint whose name mentions key usage, on a subscriber with none"
"$Z" -includeNames=e_ca_key_usage_missing,e_root_ca_key_usage_present,e_cabf_ecc_allowed_key_usages,e_key_usage_presence \
     "$D/positive/ZT-068-subscriber-no-key-usage.pem" || echo FAILED
echo
echo "observed  every key-usage lint returns NA"
echo "correct   a warning that keyUsage is absent from a subscriber certificate"
echo
echo "Note: the companion claim that no lint reports a missing"
echo "authorityKeyIdentifier was REFUTED - e_ext_authority_key_identifier_no_key_identifier"
echo "reports it, 454 times on this corpus. See REFUTED.md."
