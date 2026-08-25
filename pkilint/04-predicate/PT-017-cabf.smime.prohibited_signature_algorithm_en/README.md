# PT-017 — `cabf.smime.prohibited_signature_algorithm_encoding`'s allow-list has no entry for ECDSA-with-SHA-512

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | reproduction against a certificate generated for this lane's own `e_invalid_signature_algoid` case, executed against the pinned interpreter |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

### Observed

```
$ lint_cabf_smime_cert lint -d -f JSON clean_p521.pem
{"results": [
  ...,
  {"node_path": "certificate.tbsCertificate.signature",
   "validator": "SmimeAllowedSignatureAlgorithmEncodingValidator",
   "finding_descriptions": [{"severity": "ERROR",
     "code": "cabf.smime.prohibited_signature_algorithm_encoding",
     "message": "Prohibited encoding: 300a06082a8648ce3d040304"}]}
]}
```

`clean_p521.pem` is a conforming mailbox-validated Strict S/MIME Subscriber
Certificate whose `signatureAlgorithm` is `300a06082a8648ce3d040304` -- ECDSA
with SHA-512, the encoding for a P-521 signing key -- and nothing else about
it is wrong.

### Correct

> If the signing key is P-521, the signature SHALL use ECDSA with SHA-512.
> When encoded, the AlgorithmIdentifier SHALL be byte-for-byte identical with
> the following hex-encoded bytes: 300a06082a8648ce3d040304.

### Mechanism

`pkilint/cabf/smime/smime_key.py`'s `ALLOWED_SIGNATURE_ALGORITHM_ENCODINGS`
lists two ECDSA entries -- `300a06082a8648ce3d040302` (SHA-256, for P-256) and
`300a06082a8648ce3d040303` (SHA-384, for P-384) -- and no third. §7.1.3.2.2
states three cases, one per curve the Requirements permit (P-256, P-384,
P-521), and the set carries only the first two. A certificate using the
missing third encoding is therefore reported as prohibited by
`SmimeAllowedSignatureAlgorithmEncodingValidator.validate`, which raises
`VALIDATION_PROHIBITED_SIGNATURE_ALGORITHM` for any encoding not in the set,
with no further reasoning. This is a missing set entry, not a control-flow
question, so nothing here needed executing beyond the reproduction above.

The eleven other entries in the same set (six RSA, two `EdDSA`, three ML-DSA)
were checked by hand against §§7.1.3.2.1.2.3 and.2.4 and match the
Requirements' own hex byte-for-byte.

### Fix

Add `300a06082a8648ce3d040304` to `ALLOWED_SIGNATURE_ALGORITHM_ENCODINGS` in
`pkilint/cabf/smime/smime_key.py`.

### What was not verified
