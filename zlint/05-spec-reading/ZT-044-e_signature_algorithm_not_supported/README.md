# ZT-044 — `e_signature_algorithm_not_supported` escalates RSASSA-PSS from its own warning to an error

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `05-spec-reading` — Differing analysis of the normative text |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | zlint's own fixture pair |

## Upstream issues, adjudicated

- **#326** — e_signature_algorithm_not_supported should warn not err for RSA PSS *(closed)*
  **related.** Same lint, same algorithm, but #326 is about severity and was fixed by PR #342 in 2020. This entry reproduces against the pinned build, so the question for a maintainer is whether that fix covers this path.

## Analysis

Observed `error` on an `id-RSASSA-PSS` signature; correct `warn`, which is
what the lint's own table assigns.

```go
warnSigAlgs = map[x509.SignatureAlgorithm]bool{
    x509.SHA256WithRSAPSS: true, x509.SHA384WithRSAPSS: true,
    x509.SHA512WithRSAPSS: true,
}
...
status := lint.Error
if passSigAlgs[sigAlg] { status = lint.Pass
} else if warnSigAlgs[sigAlg] { status = lint.Warn }
```

The severity is keyed on `c.SignatureAlgorithm`, zcrypto's mapping rather than
the algorithm identifier. `zcrypto/x509/x509.go`,
`GetSignatureAlgorithmFromAI`:

```go
if !bytes.Equal(params.Hash.Parameters.FullBytes, asn1.NullBytes) ||
    !params.MGF.Algorithm.Equal(oidMGF1) ||
    !mgf1HashFunc.Algorithm.Equal(params.Hash.Algorithm) ||
    !bytes.Equal(mgf1HashFunc.Parameters.FullBytes, asn1.NullBytes) ||
    params.TrailerField != 1 {
    return UnknownSignatureAlgorithm
}
```

So an `id-RSASSA-PSS` `AlgorithmIdentifier` whose hash parameters are absent
rather than an explicit NULL, or whose salt length differs from the digest
size, arrives at `Execute` as `UnknownSignatureAlgorithm`; neither map holds
it, `status` keeps its initial `lint.Error`, and a certificate signed with an
algorithm BR §7.1.3.2 lists is reported as one the profile does not support.
The two fixtures in the reproduction carry the same algorithm OID and differ
only in that encoding; the severity moves two levels.

The parameter encoding is a real defect, and zlint reports it correctly and
separately as
`e_mp_rsassa-pss_parameters_encoding_in_signature_algorithm_correct` — "3
presentations are allowed but got the unsupported 303d06…". Nothing here
disputes that. What ZT-044 is about is the second finding, which names the
algorithm rather than its encoding, and which a CA acting on the report would
satisfy by abandoning RSASSA-PSS altogether.

This corrects an aside in [ZT-050](#zl-025), which says of that same root that
"zlint separately and correctly reports `e_public_key_type_not_allowed` and
`e_signature_algorithm_not_supported`". The first is right: BR §7.1.3.1 says
the CA "SHALL NOT use a different algorithm, such as the `id-RSASSA-PSS` (OID:
1.2.840.113549.1.1.10) algorithm identifier, to indicate an RSA key", which is
about the `subjectPublicKeyInfo`. The second is this defect — the *signature*
algorithm is in §7.1.3.2's table.

Fix: read the severity from the algorithm identifier rather than from
zcrypto's mapping — test the `id-RSASSA-PSS` OID before falling through to
`Error`. Independently, zcrypto could return a distinct value for
"`id-RSASSA-PSS`, with parameters that are not one of the three", so a caller
can tell an unrecognised algorithm from an unrecognised encoding of a
recognised one.
