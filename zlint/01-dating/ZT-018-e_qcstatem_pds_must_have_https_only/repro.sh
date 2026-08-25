#!/bin/bash
# ZT-018 — e_qcstatem_pds_must_have_https_only is dated ten years and eight
# months after the clause it enforces. Citation: "ETSI EN 319 412 - 5 V2.4.1
# (2023 - 09) / Section 4.3.4" EffectiveDate:
# util.EtsiEn319_412_5_V2_4_1_Date // 2023-09-01 QCS-4.3.4-03 -- "As a
# minimum, a URL to a PDS provided in this statement shall use the 'https'
# (https://) scheme" -- is in EN 319 412-5 **v1.1.1, January 2013**, the
# document's first version, in the same words. Verified against the complete
# series: v1.1.1, v2.1.1, v2.2.1, v2.3.1, v2.4.1, v2.5.1 and v2.6.1 all
# carry it. v2.4.1 is where zlint's author read it, not where it began. The
# clause argues its own case in the sentence before, and the argument has
# nothing to do with any version: The signature of the certificate does not
# cover the content of the PDS and hence does not protect the integrity of
# the PDS which can change over time. The case here is the earliest, from
# Mozilla bug 1481862.
set -u
Z=${ZLINT:-$HOME/.local/bin/zlint}
D=$(dirname "$0")
echo "zlint: $($Z -version 2>&1 | head -1)"
echo
openssl x509 -inform DER -in "$D/positive/ZT-018-pds-http-2018.der" -out "$D/.zl045.pem" 2>/dev/null
printf 'notBefore %s\n' "$(openssl x509 -in "$D/.zl045.pem" -noout -startdate | cut -d= -f2)"
python3 - "$D/.zl045.pem" <<'PY'
import re, sys, warnings
warnings.filterwarnings("ignore")
from cryptography import x509
c = x509.load_pem_x509_certificate(open(sys.argv[1], "rb").read())
for e in c.extensions:
    if e.oid.dotted_string == "1.3.6.1.5.5.7.1.3":
        raw = e.value.public_bytes()
        for m in re.finditer(rb"https?://[!-~]+", raw):
            print("    PDS URL:", m.group().decode())
PY
$Z -includeNames=e_qcstatem_pds_must_have_https_only "$D/.zl045.pem" 2>/dev/null
rm -f "$D/.zl045.pem"

echo
echo "observed: NE — the lint is not effective for this certificate"
echo "correct : error — the clause has said https since v1.1.1, January 2013"
echo "fix     : date the lint to EN 319 412-5 v1.1.1 rather than to the version"
echo "          in which the requirement was read. The sibling QcPDS lints,"
echo "          e_qcstatem_qcpds_valid and w_qcstatem_qcpds_lang_case, are"
echo "          dated v2.2.1 and carry requirements that are also v1.1.1's."
