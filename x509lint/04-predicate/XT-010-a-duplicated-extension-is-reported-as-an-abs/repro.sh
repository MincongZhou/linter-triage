#!/bin/bash
# XT-010 — a duplicated extension is reported as an ABSENT one, and the
# checks that extension carries are skipped. Demonstrated on
# authorityKeyIdentifier. ./positive/XT-010-repro.sh /path/to/x509lint
set -u
X="${1:-x509lint}"
D="$(cd "$(dirname "$0")" && pwd)"

echo "== the certificate carries authorityKeyIdentifier TWICE"
openssl x509 -in "$D/positive/XT-010-duplicated-akid.pem" -noout -text 2>/dev/null \
  | grep -c "X509v3 Authority Key Identifier" | sed 's/^/   occurrences: /'
echo
"$X" "$D/positive/XT-010-duplicated-akid.pem" || echo FAILED

cat <<'NOTE'

Observed (x509lint at commit 103c92f):

  E: Duplicate extension
  E: AKID missing          <- the extension is present, twice

Correct: report the duplication, which it does, and not the absence, which is
false. RFC 5280 §4.2: "A certificate MUST NOT include more than one instance of
a particular extension." That is what "Duplicate extension" says. "AKID missing"
is a second, contradictory statement about the same field.

MECHANISM

checks.c:1898, inside GetType():

        AUTHORITY_KEYID *akid = X509_get_ext_d2i(x509, NID_authority_key_identifier,
                                                 &critical, NULL);
        if (akid == NULL && critical >= 0)   SetError(ERR_INVALID);
        ...
        if (!self_signed && akid == NULL)    SetError(ERR_AKID_MISSING);

OpenSSL returns NULL and sets the critical out-param to -2 -- "extension occurs
more than once" -- when the index argument is NULL. The ERR_INVALID guard tests
`critical >= 0`, so -2 slips past it, and the absent-extension branch runs.

XT-010-get-ext-d2i.c executes that, and the same file supplies its own
control: two of its extensions are duplicated and two are not.

cc -o get-ext-d2i XT-010-get-ext-d2i.c -lcrypto ./get-ext-d2i
positive/XT-010-duplicated-akid.pem

        authorityKeyIdentifier     occurs 2  ->  NULL     critical out-param = -2
        subjectKeyIdentifier       occurs 2  ->  NULL     critical out-param = -2
        keyUsage                   occurs 1  ->  non-NULL critical out-param = 1
        basicConstraints           occurs 1  ->  non-NULL critical out-param = 1

WHAT ELSE IT REACHES

Four call sites pass NULL for the index argument and so take the
absent-extension branch on a duplicate:

checks.c:1464 keyUsage -- the whole CheckKeyUsage body is skipped
checks.c:1632 basicConstraints -- reported as ERR_NO_BASIC_CONSTRAINTS for a
CA, silently skipped for a leaf checks.c:1877 subjectKeyIdentifier
checks.c:1898 authorityKeyIdentifier -- demonstrated above

The other five sites (689 certificatePolicies, 1024 subjectAltName, 1166
crlDistributionPoints, 1295 authorityInformationAccess, 1545 extendedKeyUsage)
pass `&idx` and iterate, so they are not affected. This is a defect of four call
sites, not of the tool's approach.

Only the authorityKeyIdentifier limb is demonstrated on real material.

WHAT IT DOES NOT DO

It does not let a certificate pass. ERR_DUPLICATE_EXTENSION (checks.c:1450) is
raised for any repeated OID whatever, before any of this, so a duplicating
certificate always earns at least one error. No verdict flips; what is lost is
which requirement was broken, and what is gained is a false statement.

REACH (the corpus, 21,802 certificates, x509lint 103c92f)

6 certificates carry a duplicated extension 1 of those duplicates
authorityKeyIdentifier and draws the false AKID missing 0 duplicate keyUsage
or basicConstraints

FIX

Distinguish the two NULLs. -2 is not absence:

        if (akid == NULL && critical == -2)  SetError(ERR_DUPLICATE_EXTENSION);
        else if (akid == NULL && critical >= 0)  SetError(ERR_INVALID);
        else if (akid == NULL && !self_signed)   SetError(ERR_AKID_MISSING);

and the same at 1464, 1632 and 1877 -- or pass an index and iterate, as the
other five sites already do. NOTE
