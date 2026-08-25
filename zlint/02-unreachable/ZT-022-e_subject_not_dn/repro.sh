#!/bin/bash
# ZT-022 — e_subject_not_dn is a tautology and can never return Error.
# lints/rfc/lint_subject_not_dn.go: if reflect.TypeOf(c.Subject) !=
# reflect.TypeOf(*(new(pkix.Name))) { return &lint.LintResult{Status:
# lint.Error} } zcrypto declares Certificate.Subject as a concrete
# pkix.Name, not an interface, so reflect.TypeOf(c.Subject) is pkix.Name for
# every certificate that parses at all. The comparison is between a type and
# itself. The case certificate is a real misissued certificate (, subject
# RDN encoding incident 2462c4c8) whose subject two other zlint lints call
# malformed. This one still passes. ./positive/ZT-022-repro.sh
# /path/to/zlint
set -u
Z="${1:-zlint}"
D="$(cd "$(dirname "$0")" && pwd)"

echo "== subject of the case certificate"
openssl x509 -in "$D/positive/ZT-022-subject-not-dn-never-fires.pem" -noout -subject

echo
echo "== what zlint says about that subject"
"$Z" -includeNames=e_subject_not_dn,e_invalid_subject_rdn_order,e_subject_rdns_correct_encoding \
     "$D/positive/ZT-022-subject-not-dn-never-fires.pem" || echo FAILED

cat <<'NOTE'

Observed (zlint v3.7.1-20-g1007b1d5):

  {"e_invalid_subject_rdn_order":{"result":"error"},
   "e_subject_not_dn":{"result":"pass"},
   "e_subject_rdns_correct_encoding":{"result":"pass"}}

Over 11,714 certificates (this project's corpus) the lint returns
pass=11709, NE=5, error=0.

Settled by execution rather than by reading, since the claim rests on Go's
reflect. This program, built against the same zcrypto revision zlint pins
(v0.0.0-20260514033604-a1159eb3cad9), prints "false" for both cases:

    package main

    import (
        "fmt"
        "reflect"

        "github.com/zmap/zcrypto/x509"
        "github.com/zmap/zcrypto/x509/pkix"
    )

    func main() {
        c := new(x509.Certificate)
        fmt.Println(reflect.TypeOf(c.Subject) != reflect.TypeOf(*(new(pkix.Name))))
        c.Subject = pkix.Name{CommonName: "example.com"}
        fmt.Println(reflect.TypeOf(c.Subject) != reflect.TypeOf(*(new(pkix.Name))))
    }

    static type of Certificate.Subject : pkix.Name
    reflect.TypeOf(c.Subject)          : pkix.Name
    reflect.TypeOf(*(new(pkix.Name)))  : pkix.Name
    predicate (Error branch taken?)    : false
    populated Subject predicate        : false

A correct tool would either delete the lint or give it a body: RFC 5280
4.1.2.6 makes subject a Name, and the checkable content is whether the encoded
RDNSequence is well formed — which requires looking at c.RawSubject, not at
the static type of the field the decoder wrote into. As shipped the lint is
dead code that reports a requirement as covered. NOTE
