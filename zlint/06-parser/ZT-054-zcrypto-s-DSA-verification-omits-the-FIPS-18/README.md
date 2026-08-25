# ZT-054 — zcrypto's DSA verification omits the FIPS 186-4 hash truncation

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `06-parser` — Root cause in the decoder, not in the check |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | zlint's own `dsaCert.pem` |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

FIPS 186-4 §4.7 has the verifier use "the leftmost min(N, outlen) bits of
Hash(M)". Go's `crypto/dsa` does exactly that; zcrypto's fork computes the
bound and then does not apply it:

```go
	n := pub.Q.BitLen()
	if n%8 != 0 {
		return false
	}
	z := new(big.Int).SetBytes(hash)      // stdlib: SetBytes(hash[:n>>3])
```

`n` is assigned and never read again. Where the digest is no longer than q the
two agree; where it is longer, `z` is a different number and a correct
signature fails.

Executed against zlint's own `dsaCert.pem` — DSA-1024, so q is 160 bits,
signed with SHA-256, so the digest is 256:

```
q is 160 bits, the digest is 256 bits
zcrypto's Verify, digest untruncated : false
the same, digest truncated to q      : true
```

`openssl verify -check_ss_sig -no_check_time` accepts the same self-signature,
and rejects a copy of the certificate with one octet of the signature flipped
— so the independent check is not vacuous, which is worth stating because
`openssl verify` **without** `-check_ss_sig` does not examine a trust anchor's
own signature at all.

The consequence inside zlint is
[ZT-053](#zl-064--a-root-whose-signature-algorithm-the-parser-declines-is-judged-as-a-subordinate-ca)'s:
`SelfSigned` is false, so `util.IsRootCA` is false, so this self-signed CA is
judged under the subordinate profile — root lints NA, `e_sub_ca_*` firing. Two
different parse-level failures, one shared consequence, which is the argument
for fixing the consequence as well as each cause.

**One-line fix**: `z := new(big.Int).SetBytes(hash[:min(n>>3, len(hash))])`,
restoring the two lines the fork dropped.
