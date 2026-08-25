# ZT-079 — `w_ext_aia_access_location_missing` cannot fire when `id-ad-caIssuers` names a non-URI location

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `02-unreachable` — Checks that cannot fire |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | reproduced against **zlint's own test fixture** |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

> An authorityInfoAccess extension may include multiple instances of the
> id-ad-caIssuers accessMethod. [...] When the id-ad-caIssuers accessMethod
> is used, at least one instance SHOULD specify an accessLocation that is an
> HTTP [RFC2616] or LDAP [RFC4516] URI.

```go
func (l *aiaNoHTTPorLDAP) CheckApplies(c *x509.Certificate) bool {
	return util.IsExtInCert(c, util.AiaOID) && c.IssuingCertificateURL != nil
}
```

**`c.IssuingCertificateURL` is populated only from `id-ad-caIssuers` entries
whose `accessLocation` is already a `uniformResourceIdentifier`.** Read
directly from the pinned `zcrypto` dependency
(`github.com/zmap/zcrypto@v0.0.0-20260514033604-a1159eb3cad9/x509/x509.go`,
the `oidExtensionAuthorityInfoAccess` parsing branch):

```go
for _, v := range aia {
    // GeneralName: uniformResourceIdentifier [6] IA5String
    if v.Location.Tag != 6 {
        continue
    }
    if v.Method.Equal(oidAuthorityInfoAccessOcsp) {
        out.OCSPServer = append(out.OCSPServer, string(v.Location.Bytes))
    } else if v.Method.Equal(oidAuthorityInfoAccessIssuers) {
        out.IssuingCertificateURL = append(out.IssuingCertificateURL, string(v.Location.Bytes))
    }
}
```

A `GeneralName` alternative other than `[6] uniformResourceIdentifier` — a
`directoryName`, for instance — is silently dropped from
`IssuingCertificateURL`, whatever its `accessMethod`. So a certificate whose
*only* `id-ad-caIssuers` entry is, say, a `directoryName` has
`IssuingCertificateURL == nil`, `CheckApplies` returns `false`, and the check
never runs — even though `id-ad-caIssuers` **is** used, which is the clause's
own condition for the SHOULD to bind.

**observed**: `NA` on — **zlint's own test fixture**, named by its own authors
for exactly this shape. Its `authorityInfoAccess` carries one
`id-ad-caIssuers` entry whose `accessLocation` is an `rfc822Name` (an email
address), not a URI:

```
Authority Information Access:
    CA Issuers - email:http://issuers.example.com/
```

```
$ zlint -includeNames w_ext_aia_access_location_missing aiaWrongGeneralName.pem
{"w_ext_aia_access_location_missing":{"result":"NA"}}
```

Per the gap-reporting skill, a tool failing on its own test data is the
strongest report available; this lane's own fabricated fixture (a
`directoryName` accessLocation instead, same mechanism) reproduces the
identical `NA` and is kept below as a second, independent shape.

```
$ zlint -includeNames w_ext_aia_access_location_missing synthetic-aia-caissuers-directoryname-only.pem
{"w_ext_aia_access_location_missing":{"result":"NA"}}
```

**correct**: `warn` on both. `id-ad-caIssuers` is used, and no instance names
an HTTP or LDAP URI, which is exactly what the SHOULD is about.

**mechanism**: not a reading disagreement and not a language-semantics trap —
`v.Location.Tag != 6 { continue }` is unambiguous in Go, confirmed by reading
the exact field the check's own `CheckApplies` depends on. The defect is a
gate built from a narrower predicate ("a URI-typed accessLocation already
exists") than the clause it is meant to detect the absence of ("no instance is
a URI") — the two coincide everywhere except the one shape that most needs the
check: a wholly non-URI `id-ad-caIssuers` claim.

**fix**: gate applicability on the accessMethod alone — read every
`AccessDescription`'s `accessMethod` field regardless of what type its
`accessLocation` is, the way `IssuingCertificateURL`'s producing loop reads
`v.Method` before filtering on `v.Location.Tag`, rather than reusing a field
already filtered for a different purpose.
