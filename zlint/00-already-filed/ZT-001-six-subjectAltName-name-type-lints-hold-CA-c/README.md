# ZT-001 — six subjectAltName name-type lints hold CA certificates to a Subscriber clause

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `00-already-filed` — Already on your issue tracker |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | real trust-store intermediate, real end-entity control |
| **Would otherwise sit in** | see the adjudication below |

## Upstream issues, adjudicated

- **#591** — BUG: lint "e_ext_san_rfc822_name_present" should only be applied to SSL/TLS subscriber certificates *(open)*
  **duplicate.** Same claim, narrower: #591 reports e_ext_san_rfc822_name_present on a CA certificate. This entry finds the identical CheckApplies in all six SAN name-type lints. Open since 2021.

## Analysis

Observed `error` on a subordinate CA whose `subjectAltName` carries a
`directoryName`; correct `NA`.

`CheckApplies` for all six is the presence of the extension and nothing else:

```go
func (l *SANDirName) CheckApplies(c *x509.Certificate) bool {
    return util.IsExtInCert(c, util.SubjectAlternateNameOID)
}
```

The clause behind it, cited by every one of the six as `BRs: 7.1.4.2.1`, is a
Subscriber Certificate clause. §7.1.4.2 is headed "Subject Information —
Subscriber Certificates" from BR 1.4.8; §7.1.4.3 profiles Root and Subordinate
CA subject information and states no `subjectAltName` name-type table at all;
in BR 2.0.0 the same clause is §7.1.2.7.12, "Subscriber Certificate Subject
Alternative Name". A CA certificate's `subjectAltName` reaches the CA
extension tables only as "Any other extension: NOT RECOMMENDED", so the
strongest thing the document says about a `directoryName` there is that it is
not recommended.

zlint settles the reading itself. `lint_ext_san_missing.go` cites the
identical string, `BRs: 7.1.4.2.1`, for the Required/Optional row of the same
table, describes it as "**Subscriber** certificates MUST contain the Subject
Alternate Name extension", and guards with `!util.IsCACert(c)`. One clause,
one table row, two scopes in one package — and both appear in a single line of
output on the reproduction's first certificate:

```
e_ext_san_directory_name_present   error
e_ext_san_missing                  NA
```

| lint | firings | CA certificates among them |
|---|---|---|
| `e_ext_san_directory_name_present` | 444 | 411 |
| `e_ext_san_rfc822_name_present` | 438 | 385 |
| `e_ext_san_uniform_resource_identifier_present` | 53 | 30 |
| `e_ext_san_other_name_present` | 11 | 4 |
| `e_ext_san_edi_party_name_present` | 3 | 1 |
| `e_ext_san_registered_id_present` | 4 | 0 |

The breadth is deliberate rather than an oversight, and saying so is part of
the report: the directoryName lint's positive fixtures are
`SANDirectoryNameBeginning.pem` and `SANDirectoryNameEnd.pem`, both `CA:TRUE`
and both asserted `lint.Error`, and its negative fixture is named
`SANCaGood.pem`. So the fix costs new fixtures and turns two existing
positives into `NA`. That is the price of the fix, not an argument against it
— six lints reading a clause more broadly than the lint beside them that cites
it is still one of the two readings being wrong, and the document is not
ambiguous about which.

Fix: open each of the six `CheckApplies` with `util.IsSubscriberCert(c)`,
matching `lint_ext_san_missing.go` on the same clause.
