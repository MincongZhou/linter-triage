# ZT-053 — a root whose signature algorithm the parser declines is judged as a subordinate CA

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `06-parser` — Root cause in the decoder, not in the check |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | D-TRUST Root CA 1 2017, with a second real root as the control |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

zcrypto sets `Certificate.SelfSigned` only when the subject and issuer names
match **and** the self-signature verifies, and zlint's role predicates read
nothing else:

```go
func IsRootCA(c *x509.Certificate) bool { return IsCACert(c) &&  IsSelfSigned(c) }
func IsSubCA(c *x509.Certificate)  bool { return IsCACert(c) && !IsSelfSigned(c) }
```

So "this parser could not check the signature" and "this is not a root" are
the same answer, and every lint scoped by role inherits it — 147 of the 427
read `IsSubCA`, `IsRootCA`, `IsCACert` or `IsSubscriberCert`.

D-TRUST Root CA 1 2017 reaches that branch through
`x509.GetSignatureAlgorithmFromAI`, which refuses an RSASSA-PSS
`AlgorithmIdentifier` whose `hashAlgorithm` parameters are **absent**:

```go
if !bytes.Equal(params.Hash.Parameters.FullBytes, asn1.NullBytes) || ...
    return UnknownSignatureAlgorithm
```

RFC 4055 §2.1 is explicit in both directions: "The correct encoding is to omit
the parameters field", and "All implementations MUST accept both NULL and
absent parameters as legal and equivalent encodings." Go's own `crypto/x509`
accepts either. **So does zcrypto's unexported `getSignatureAlgorithmFromAI`,
in the same file** — it tests `len(...) != 0 && !bytes.Equal(...)`. The two
functions differ by that one condition; CRLs take the lenient one and
certificates take the strict one.

The consequences on that root, all measured:

| | D-TRUST (absent) | control (NULL) |
|---|---|---|
| `e_root_ca_key_usage_present` | NA | pass |
| `e_root_ca_key_usage_must_be_critical` | NA | pass |
| `e_root_ca_extended_key_usage_present` | NA | pass |
| `w_root_ca_contains_cert_policy` | NA | pass |
| `w_root_ca_basic_constraints_path_len_constraint_field_present` | NA | pass |
| `e_sub_ca_certificate_policies_missing` | **error** | NA |
| `e_sub_ca_aia_missing` | **error** | NA |
| `n_sub_ca_eku_missing` | info | NA |
| `w_sub_ca_aia_does_not_contain_issuing_ca_url` | warn | NA |
| `e_signature_algorithm_not_supported` | **error** | warn |

The control is a real root too — Staat der Nederlanden G4 Root Publ G-SMIME
2024, also SHA-512 RSASSA-PSS, also self-signed. It differs from the subject
in two octets: the `05 00` NULL inside the PSS `hashAlgorithm`.

High, and by both halves of the definition. The five root-profile lints report
nothing about a root they were written for, which is conformance asserted
without being verified; and the two errors are misissuance findings against a
certificate that is not required to carry either extension — §7.1.2.1.2 states
`certificatePolicies` NOT RECOMMENDED for a root, the exact inverse of the
clause it is being reported under. The subject controls whether this happens,
since the subject chooses the encoding.

**One-line fix**: give `GetSignatureAlgorithmFromAI` the condition its
unexported sibling already has. The deeper fix is `IsRootCA`, which should not
depend on a signature check the parser may be unable to perform — an
unverifiable self-signature makes a certificate *broken*, not *subordinate*.
