# ZT-058 — `e_org_validated_invalid_cn` panics on an OV S/MIME certificate with no organizationName

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `07-robustness` — Panics, run-ending failures, and non-determinism |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | zlint's own `organization_validated_with_matching_country.pem`, with `sub1_sm1_ov1_cne0_cno0_eff1.pem` as the control |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```go
if isEmail(c.Subject.CommonName) ||
	c.Subject.CommonName == c.Subject.Organization[0] {
```

`Organization` is a `[]string` and is indexed without a length check. Go's
short-circuit spares a certificate whose `commonName` is an email address;
every other OV S/MIME certificate with an empty `Organization` panics.

```
{"e_org_validated_invalid_cn":{"result":"fatal","details":"'e_org_validated_invalid_cn'
 panicked. Error: runtime error: index out of range [0] with length 0"}}
```

**The population is the one that matters most.** S/MIME BR § 7.1.4.2.2
requires `organizationName` in an Organization-Validated certificate, so the
lint crashes precisely on the certificates that breach the requirement next
door.

Fix: guard the index. An OV certificate with no `organizationName` cannot have
a `commonName` matching it, so `error` is the answer once the index is safe.
