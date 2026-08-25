#!/bin/bash
# CT-005 — a name issued lawfully under a gTLD that has since been withdrawn
# is reported as naming a top-level domain that does not exist. cablint's
# TLD data is two snapshots of what is delegated TODAY, and the one file
# that carries a delegation-date column has it discarded on read.
# Certificates: both real -- one from the Bugzilla archive, one is zlint's
# own fixture for this exact case, named `dnsNameWasValidTLD`.
# ./positive/CT-005-repro.sh /path/to/certlint-checkout
set -u
CL="${1:-.}"
D="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

run() {
  openssl x509 -in "$1" -outform der -out "$T/c.der" 2>/dev/null
  (cd "$CL" && ruby -Ilib -Iext bin/cablint "$T/c.der" 2>/dev/null) | sed 's/\t.*//' \
    | grep -i "TLD" | sort -u || echo "   (nothing about the TLD)"
}

for pair in "positive/CT-005-withdrawn-tld-cancerresearch.pem:.cancerresearch — delegated 2014-07-03, withdrawn 2022-10-05" \
            "positive/CT-005-withdrawn-tld-mcdonalds.pem:.mcdonalds — delegated 2016-08-08, withdrawn 2017-08-31"; do
  IFS=: read -r file note <<< "$pair"
  echo "== $note"
  openssl x509 -in "$D/$file" -noout -startdate -ext subjectAltName 2>/dev/null \
    | grep -v "^X509v3" | cut -c1-96 | sed 's/^/      /'
  run "$D/$file" | sed 's/^/   /'
  echo
done

cat <<'NOTE'
Observed: E: Unknown TLD in SAN, against two certificates whose names were
under a delegated gTLD on the day each was issued. The first was issued
2022-07-22 and .cancerresearch was withdrawn 2022-10-05, eleven weeks later.
The second is dated 2016-08-08, the very day .mcdonalds was delegated.
Correct: silence. A registry that carried the label at issuance is the only
registry that matters to a certificate issued then.

THE MECHANISM

    iananames.rb:93   # from https://newgtlds.icann.org/newgtlds.csv
    iananames.rb:96   @iana_tlds[l.split(',').first.downcase] = :public
    iananames.rb:105  # from http://www.internic.net/domain/root.zone
    iananames.rb:109  @iana_tlds[tld] = :public

Two files, both snapshots of what is delegated now, and a flat label -> :public
map with no room for a date. `newgtlds.csv`'s header is

    "tld","u-label","registry-operator","date-of-contract-signature",
    "application-id","delegation-date"

and `l.split(',').first` takes the label and discards the rest, `delegation-date`
included. Neither `cancerresearch` nor `mcdonalds` appears in either file today,
so no delegation date would have helped these two: what is missing is a
REMOVAL date, which a list of current delegations cannot carry.

REACH

Four certificates over the corpus (21,802). It is small because withdrawals are
rare -- 137 labels in the whole history of the programme -- and it grows with
every one, retroactively, over the entire back catalogue of certificates
issued under the withdrawn label.

FIX

A dated source. ICANN's gTLD v2 JSON registry carries both a delegation and a
removal date per label; zlint derives `util/gtld_map.go` from it with its own
`zlint-gtld-update` command, and that map is the only machine-readable form of
the history in either vendored tree. The lookup then becomes "was this label
delegated on the certificate's notBefore" rather than "is it delegated now".

zlint gets this right and ships the fixture -- `dnsNameWasValidTLD.pem`, used
here as the second subject -- which is why the same input is a pass there and
an error here. NOTE
