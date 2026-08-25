# ZT-028 — `IsDelegatedOCSPResponderCert` calls any OCSPSigning EKU a delegated responder

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `03-scope` — Applied outside the population the clause governs |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | real trust-store intermediate, zlint's own fixture as control |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

Observed `error` on a subordinate CA; correct `NA`.

```go
func (l *...) CheckApplies(c *x509.Certificate) bool {
    return util.IsDelegatedOCSPResponderCert(c)
}

// util/ca.go
func IsDelegatedOCSPResponderCert(cert *x509.Certificate) bool {
    return HasEKU(cert, x509.ExtKeyUsageOcspSigning)
}
```

Inclusion of the purpose, on any certificate. A subordinate CA listing
`id-kp-OCSPSigning` beside `serverAuth` and `clientAuth` — which is how a CA
declares that it signs OCSP responses under its own key — is then required, at
error, to carry `id-pkix-ocsp-nocheck`.

It is not a delegated responder, and three documents say so in the same
direction. RFC 6960 §4.2.2.2 gives three acceptance criteria for a response
signer, and the CA's own certificate is criterion 2, distinct from criterion
3's "includes a value of id-kp-OCSPSigning … and is issued by the CA".
§4.2.2.2.1, which introduces `id-pkix-ocsp-nocheck`, is headed "Revocation
Checking of an **Authorized Responder**". BR §7.1.2.8 opens "If the Issuing CA
does not directly sign OCSP responses, it MAY make use of an OCSP Authorized
Responder", and §7.1.2.8.6 places the MUST inside that profile. The CA
certificate extension tables do not list `id-pkix-ocsp-nocheck` at all.

So the lint requires at error an extension the governing document reaches only
as "NOT RECOMMENDED" for the certificate being judged, and whose meaning —
that the holder's own revocation status need not be checked — is not a
property to assert of a CA.

`OverrideFrameworkFilter: true` is set, so `util.IsServerAuthCert` does not
narrow the population either; the guard above is the whole of it. Unlike
[ZT-001](#zl-020) the fix breaks no test: the lint's 32-case fixture matrix
varies OCSPSigning, serverAuth, emailProtection, anyEKU and nocheck, and every
case in it is an end-entity certificate. Nothing asserts what a CA should
draw.

Fix: `return util.IsDelegatedOCSPResponderCert(c) && !util.IsCACert(c)`, or
add the `basicConstraints` test inside `util.IsDelegatedOCSPResponderCert`,
whose name already claims more than `HasEKU` delivers.
