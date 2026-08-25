#!/bin/bash
# ZT-010 - util.CABV201Date is the effective date of the wrong ballot.
# Ballot 201 (.onion Revisions, EVG 1.6.5) was adopted 2017-06-08 and
# effective 2017-07-08 per the EVG's own revision table. util/time.go sets
# CABV201Date to 2017-07-28, which is the effective date of the next row -
# ballot 192 / EVG 1.6.6, the Notary Revision, which is unrelated to .onion.
# It is the sole EffectiveDate of the only lint that checks the
# TorServiceDescriptor extension, so EV .onion certificates issued in those
# twenty days return NE. Separately: the extension dates from ballot 144 /
# EVG 1.5.3, effective 2015-02-18, so even the corrected constant leaves two
# years unchecked. Certificates: fabricated, differing only in notBefore.
# ./positive/ZT-010-repro.sh /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"
L=e_ext_tor_service_descriptor_hash_invalid

echo "== notBefore 2017-07-10, inside the ballot-201 window"
"$Z" -includeNames="$L" "$D/positive/ZT-010-tor-descriptor-ballot-201-window.pem" || echo FAILED
echo "== notBefore 2017-07-28, on CABV201Date  (control)"
"$Z" -includeNames="$L" "$D/negative/ZT-010-control-on-cabv201date.pem" || echo FAILED
echo
echo "observed  NE inside the window, error on the constant"
echo "correct   error for both - ballot 201 took effect 2017-07-08"
