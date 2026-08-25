#!/bin/bash
# ZT-034 - e_sub_cert_cert_policy_empty passes the empty extension it names.
# certificatePolicies is present and its value is the two bytes 30 00: the
# certificate asserts zero policy identifiers. The lint's guard is
# `c.PolicyIdentifiers != nil`, and zcrypto sets that to a non-nil
# zero-length slice for an empty SEQUENCE, so the guard holds and the lint
# passes. `len(c.PolicyIdentifiers) > 0` is the intended test. Certificate:
# zlint's own fixture v3/testdata/empty_seq_of_cps.pem, unmodified.
# ./positive/ZT-034-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"

"$Z" -includeNames=e_sub_cert_cert_policy_empty "$D/positive/ZT-034-empty-certificate-policies.pem" || echo FAILED
echo
echo "observed  pass"
echo "correct   error - the extension is present and asserts no policy identifier"
