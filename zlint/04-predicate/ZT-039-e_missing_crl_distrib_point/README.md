# ZT-039 — `e_missing_crl_distrib_point` tests for an OCSP URI where the clause names an accessMethod

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | fabricated (recipe in the script) |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

Observed `error` on a subscriber certificate whose
`authorityInformationAccess` carries an `id-ad-ocsp` accessMethod with a
`dNSName` accessLocation; correct `pass`.

```go
func (l *MissingCRLDistribPoint) Execute(c *x509.Certificate) *lint.LintResult {
    if len(c.CRLDistributionPoints) == 0 && len(c.OCSPServer) == 0 {
```

`c.OCSPServer` is not the set of `id-ad-ocsp` access descriptions. zcrypto
discards an access description on the general-name tag *before* it examines
the method — `x509/x509.go`, parsing the AIA extension:

```go
for _, v := range aia {
    // GeneralName: uniformResourceIdentifier [6] IA5String
    if v.Location.Tag != 6 {
        continue
    }
    if v.Method.Equal(oidAuthorityInfoAccessOcsp) {
        out.OCSPServer = append(out.OCSPServer, string(v.Location.Bytes))
```

So a certificate that does include an `id-ad-ocsp` accessMethod, written with
any accessLocation other than a `uniformResourceIdentifier`, reaches `Execute`
with an empty `OCSPServer` and is faulted for a missing
`cRLDistributionPoints` extension.

BR §7.1.2.11.2 states the condition on the accessMethod:

> Subscriber Certificates that 1) do not qualify as "Short-lived Subscriber
> Certificates" and 2) do not include an Authority Information Access extension
> with an `id-ad-ocsp` accessMethod.

and the note under the Subscriber extension table repeats the same wording.
The lint's own `Description` paraphrases it as "lacking an OCSP pointer",
which is looser than the clause its `Citation` names.

The malformed accessLocation is a real defect, and zlint reports it correctly
and separately as `e_aia_must_contain_permitted_access_method` — "Certificate
has an invalid GeneralName with tag 2 in an accessLocation". Nothing here
disputes that finding. ZT-039 is the *second* error: a demand for an extension
the cited clause does not require, which a CA acting on the report would
satisfy by adding `cRLDistributionPoints` while leaving the actual defect in
place.

The tag test lives in zcrypto and reaches the other `OCSPServer` readers too,
but those are lints *about* the URLs — `e_aia_ocsp_must_have_http_only`,
`e_sub_cert_aia_does_not_contain_ocsp_url`, `e_aia_unique_locations` — where
iterating URIs is the question being asked. `e_missing_crl_distrib_point` is
the one place a URI list stands in for a clause about a method.

Fix: test the accessMethod the clause names. zlint has `util.AiaOID` and no
constant for `id-ad-ocsp` itself, so the lint-local fix is to unmarshal
`c.ExtensionsMap[util.AiaOID.String]` and match the method OID whatever the
accessLocation type — `lint_ext_cannot_be_empty_seq.go` already reads raw
extensions that way. The fix one level down is for zcrypto to record the
`id-ad-ocsp` descriptions it currently drops.
