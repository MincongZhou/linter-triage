# ZT-024 — the two RSA structure lints have no reachable input

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `02-unreachable` — Checks that cannot fire |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool |
| **Cases** | positive/ and negative/ |
| **Verified against** | fabricated pair |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

Observed a parse refusal and 0 bytes of JSON; correct a finding.

`e_rsa_exp_negative` ("RSA public key exponent MUST be positive") and
`e_rsa_no_public_key` ("The RSA public key should be present") both describe a
`subjectPublicKeyInfo` that zcrypto refuses before any lint runs.
`x509/x509.go`, `parsePublicKey`, `case RSA`:

```go
p := new(pkcs1PublicKey)
rest, err := asn1.Unmarshal(asn1Data, p)
if err != nil { return nil, err }
...
if !asn1.AllowPermissiveParsing {
    if p.N.Sign() <= 0 { return nil, errors.New("...modulus...") }
    if p.E.Sign() <= 0 { return nil, errors.New("...exponent...") }
}
return &rsa.PublicKey{E: p.E, N: p.N}, nil
```

and the caller at `x509.go:1651` returns that error rather than recording it.

`e_rsa_exp_negative` fires when `key.E` is negative, which is exactly the
certificate the sign check refuses. `e_rsa_no_public_key` fires when
`PublicKeyAlgorithm` is RSA and `PublicKey` is not an `*rsa.PublicKey`; the
branch above has two exits, an error and an `*rsa.PublicKey`, and
`getPublicKeyAlgorithmFromOID` maps only `1.2.840.113549.1.1.1` to RSA. There
is no third outcome for either lint to see.

The modulus is a conforming 2048 bits in both, so nothing but the exponent and
the key body differs from the control. The refusal is the issue, so two of the
three do not decode.

The two are worth keeping apart. `e_rsa_exp_negative` has a reachable body
under `asn1.AllowPermissiveParsing`, which exists in zcrypto and is set
nowhere in zlint v3, so a caller embedding the library could enable it and the
lint would work. `e_rsa_no_public_key` would still not fire, because what
stands in its way is not a parse strictness setting but a return type.

`e_rsa_no_public_key` has no test file at all.

Fix: report the malformation as a finding rather than as a refusal, or delete
the two lints.
