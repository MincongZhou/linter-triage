# ZT-032 — `e_algorithm_identifier_improper_encoding` has no scope test

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `03-scope` — Applied outside the population the clause governs |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | zlint's `ed25519_legacy_digital_signature_ku.pem`, with its `dsaCert.pem` as the control |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

BR § 7.1.3.1 states four permitted `subjectPublicKeyInfo`
`AlgorithmIdentifier` encodings byte for byte — RSA, P-256, P-384, P-521 — and
closes "No other encodings are permitted." The lint holds those four and
compares. That part is right.

```go
func (l *algorithmObjectIdentifierEncoding) CheckApplies(c *x509.Certificate) bool {
	// always check if the public key is one of the four explicitly specified encodings
	return true
}
```

**The CA/Browser Forum S/MIME Baseline Requirements state their own § 7.1.3.1
with a different list.** It has included `id-Ed25519` and `id-Ed448` since
v1.0.0 (2023-09-01), and v1.0.11 added ML-DSA and ML-KEM. So an Ed25519 S/MIME
certificate conforms to the document that governs it and this lint condemns it
anyway, citing `BRs: 7.1.3.1` — a clause BR § 1.1 addresses to certificates
for TLS server authentication.

**The control is inside zlint itself.** On the same certificate and the same
field, two lints give opposite answers:

```
e_algorithm_identifier_improper_encoding: error
  The encoded AlgorithmObjectIdentifier "300506032b6570" inside the
  SubjectPublicKeyInfo field is not allowed
e_invalid_legacy_spki_algoid: pass
```

The second is zlint's own S/MIME reading of § 7.1.3.1, and it is the one
reading the document that applies. `dsaCert.pem` — a DSA key in a TLS
certificate — is reported, which proves the byte comparison works and that
scope is the whole defect.

**A slip rather than a convention.** Of the 172 lint files on zlint's
`cabf_br` shelf, **157 carry a conditional `CheckApplies`**; 15 return `true`
unconditionally, and most of those read a field every certificate has. The
S/MIME predicates this one needs are already in `util`.

**Medium.** It publishes a conformance failure that is not one, and zlint's
results are ground truth other tools and CAs consume. Not High: nothing about
a certificate suppresses it, it always fires, and it takes no other result
down with it.

**the population here and a wider population than that.** All four are zlint's
own S/MIME fixtures, because Ed25519 in a public S/MIME certificate is still
rare. It will not stay rare: the S/MIME BR has permitted the Edwards curves
since 2023 and the post-quantum algorithms since 2025, and this lint reports
every one of them.

Fix: give `CheckApplies` a scope test.
