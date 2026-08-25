#!/bin/bash
# ZT-037 - util.IsOnionV2Address reads the wrong label. It checks labels[0]
# for the 16-character base32 address. Its own doc comment says "the
# second-to-the-right most label", and IsOnionV3Address plus
# lint_san_dns_name_onion_invalid.go both use labels[len(labels)-2]. For
# www.<v2addr>.onion the helper inspects "www", returns false, and the only
# lint that checks for a TorServiceDescriptor extension never applies.
# Certificates: fabricated. Two EV leaves (policy 2.23.140.1.1) from a
# throwaway CA, no TorServiceDescriptor extension, differing only in the
# www. label. ./positive/ZT-037-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
L=e_ext_tor_service_descriptor_hash_invalid

echo "== www.<v2addr>.onion"
"$Z" -includeNames="$L" "$D/positive/ZT-037-onion-v2-behind-subdomain.pem" || echo FAILED
echo "== <v2addr>.onion  (control)"
"$Z" -includeNames="$L" "$D/negative/ZT-037-control-onion-v2-bare.pem" || echo FAILED
echo
echo "observed  NA for the subdomain form, error for the bare form"
echo "correct   error for both - both are EV certificates for a v2 onion"
echo "          service with no TorServiceDescriptor extension"
