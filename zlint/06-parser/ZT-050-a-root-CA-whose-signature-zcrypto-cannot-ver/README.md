# ZT-050 — a root CA whose signature zcrypto cannot verify is linted as a subordinate CA

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `06-parser` — Root cause in the decoder, not in the check |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | real trust-store root, real root control |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

Observed `NA` on every Root CA lint and `error` from the Subordinate CA
profile, on D-TRUST Root CA 1 2017; correct is the Root CA profile.

The whole CA profile turns on one boolean:

```go
func IsRootCA(c *x509.Certificate) bool { return IsCACert(c) && IsSelfSigned(c) }
func IsSubCA(c *x509.Certificate)  bool { return IsCACert(c) && !IsSelfSigned(c) }
func IsSelfSigned(c *x509.Certificate) bool { return c.SelfSigned }
```

and zcrypto sets `SelfSigned` only when the self-signature *verifies*:

```go
if bytes.Equal(out.RawSubject, out.RawIssuer) {
    if err := out.CheckSignature(out.SignatureAlgorithm,
                                 out.RawTBSCertificate, out.Signature); err == nil {
        out.SelfSigned = true
    }
}
```

So `IsSubCA` is true not only for a certificate that is not self-signed but
for every self-issued CA whose signature zcrypto *declined to check*. There is
no third state, and nothing reports that the question was not answered.

The reachable trigger is an `id-RSASSA-PSS` (1.2.840.113549.1.1.10)
`subjectPublicKeyInfo`. zcrypto does not recognise the key:

```go
func getPublicKeyAlgorithmFromOID(oid asn1.ObjectIdentifier) PublicKeyAlgorithm {
    switch {
    case oid.Equal(oidPublicKeyRSA):   return RSA
    ...
    }
    return UnknownPublicKeyAlgorithm
}
```

`oidSignatureRSAPSS` is declared in the same file; the OID is absent only from
the key side. Executed against the pinned zcrypto rather than inferred:

```
SelfSigned=false IsCA=true sigAlgo=0(0) pubAlgo=unknown_algorithm
CheckSignature against own key: x509: cannot verify signature: algorithm unimplemented
```

`openssl verify -check_ss_sig` on the same bytes reports OK, so the signature
is sound and only zcrypto declines to read it.

zlint separately and correctly reports `e_public_key_type_not_allowed` on this
certificate: an `id-RSASSA-PSS` SPKI is prohibited by Mozilla Root Store
Policy §5.1.1 and by BR §7.1.3.1. Nothing here disputes that. It also reports
`e_signature_algorithm_not_supported`, which the sentence here originally
called correct as well; [ZT-044](#zl-031) shows it is not — the *signature*
algorithm is in BR §7.1.3.2's table, and the escalation from that lint's own
`warn` comes from the same zcrypto recognition limit by a different route. The
defect recorded here is that the prohibited encoding *also* silently changes
which profile the certificate is linted against — BR §7.1.2.10 lists
`authorityInformationAccess` and `certificatePolicies` as NOT RECOMMENDED for
Root CA Certificates, and zlint faults their absence under the Subordinate CA
profile instead.

This is the shape [README.md](README.md#severity) calls the serious one: the
subject of the check controls whether the check runs. An unrecognised key OID,
an unrecognised signature OID, or a signature that genuinely does not verify
all land in the same place.

A fourth certificate lands in the same profile switch by the plain route:,
self-issued with an RSA signature `AlgorithmIdentifier` whose absent NULL
parameter openssl also rejects.

An adjacent case is recorded but not numbered: is self-issued with a
`dsa-with-sha256` signature that openssl and python cryptography both verify
and zcrypto reports as "DSA verification failure". It lands in the same
profile switch by the same route. It is left unnumbered here because the
arithmetic behind that disagreement has not been isolated, and a number
asserts a defect has been.

Fix: add the `id-RSASSA-PSS` OID to `getPublicKeyAlgorithmFromOID`, parsing
the key as RSA — RFC 4055 §3.1 states the `subjectPublicKey` for
`id-RSASSA-PSS` is an `RSAPublicKey`, so nothing downstream changes.
Independently: give `util.IsSubCA` a third answer, so a self-issued CA whose
signature could not be checked falls into neither profile rather than silently
into one.
