# ZT-033 — `e_sub_cert_or_sub_ca_using_sha1` applies to Root CA certificates

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `03-scope` — Applied outside the population the clause governs |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ |
| **Verified against** | zlint's own `rsawithsha1after2016.pem` |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```go
func (l *sigAlgTestsSHA1) CheckApplies(c *x509.Certificate) bool {
	return true
}
```

The lint's `Name` says `sub_cert_or_sub_ca`. Its `Description` says
"Subscriber certificates or Subordinate CA certificates". Its `EffectiveDate`
is `util.NO_SHA1`, ballot 118's cliff.

> Effective 1 January 2016, CAs MUST NOT issue any new Subscriber certificates
> or Subordinate CA certificates using the SHA-1 hash algorithm. … **This
> Section 9.4.2 does not apply to Root CA or CA cross certificates. CAs MAY
> continue to use their existing SHA-1 Root Certificates.**

A root's self-signature is verified by nobody — trust in a root comes from the
store — which is why the exemption exists, and why sunsetting the *remaining*
SHA-1 uses needed a separate ballot in 2026. `rsawithsha1after2016.pem` is
self-signed, `CA:TRUE`, SHA-1, `notBefore` 2016-04-25, and the lint returns
`error`.

**The second exemption is harder and is not claimed here.** § 9.4.2 also
exempts "CA cross certificates", and a cross-certificate is not
distinguishable from an ordinary subordinate CA certificate by looking at one
certificate — both are `CA:TRUE` with an issuer that is not the subject.

Fix: `CheckApplies` should test the role — `util.IsSubCert(c) || util.IsSubCA(c)` — rather than returning `true`.

The counterpart rule here scopes to subscribers and subordinate CAs and so
declines this certificate. Its `REASONING.md` claimed "zlint scopes
identically", which was never true and is corrected.
