# ZT-049 — `e_crl_auth_key_id_only_contains_keyid` cannot see the field it forbids

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `06-parser` — Root cause in the decoder, not in the check |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | real CRL; control zlint's own fixture `v3/testdata/crlWithAuthKeyIDContainsAuthorityCertIssuer.pem` |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

Observed `pass`; correct `error`.

The guard decodes the AuthorityKeyIdentifier extension as

```go
type authKey struct {
    KeyIdentifier             []byte   `asn1:"optional,tag:0"`
    AuthorityCertIssuer       []byte   `asn1:"optional,tag:1"`
    AuthorityCertSerialNumber *big.Int `asn1:"optional,tag:2"`
}
```

and errors when `AuthorityCertIssuer != nil || AuthorityCertSerialNumber != nil`. `authorityCertIssuer` is `GeneralNames` — a SEQUENCE, always constructed — but the struct tag asks `encoding/asn1` to place it in a `[]byte` through an implicit tag, which the package will not do for a constructed element. The field is left nil rather than erroring, the guard's first disjunct never sees it, and a CRL carrying the forbidden field passes.

zlint's own test asserts `Error` against
`crlWithAuthKeyIDContainsAuthorityCertIssuer.pem`, and the binary agrees — but
that fixture encodes the field as **primitive** `[1]` (`81 0a
8208726f6f742e646e73`), which is not valid DER for `GeneralNames`, and which
`[]byte` accepts for the different reason that a primitive octet string is
exactly what `[]byte` expects. Against DER encoded the only way the type
allows — `a1 69 a4 67 30 65 31 0b...`, constructed, on the real CRL — the
guard is blind. The test is correct given its fixture; the fixture does not
encode the shape the lint's own doc comment describes.

pkilint corroborates the field is genuinely present on this class of CRL: on
`full-0d34dd618012.crl` (also in the archive, not shipped with this
reproduction) it reports at node path
`certificateList.tbsCertList.crlExtensions.0.extnValue.authorityKeyIdentifier.authorityCertSerialNumber`.

Fix: decode tag 1 into an `asn1.RawValue`, or into a properly typed
`GeneralNames`, so a constructed element matches instead of being skipped.
