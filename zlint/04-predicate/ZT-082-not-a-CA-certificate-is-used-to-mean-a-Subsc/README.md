# ZT-082 — "not a CA certificate" is used to mean "a Subscriber Certificate"

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl, python3 |
| **Cases** | positive/ and negative/ |
| **Verified against** | two real corpus certificates |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```
$ zlint positive/ZT-082-delegated-ocsp-responder.pem     # EKU is id-kp-OCSPSigning and nothing else
error  e_ext_san_missing
error  e_subject_common_name_not_from_san
error  e_sub_cert_locality_name_must_appear
error  e_sub_cert_province_must_appear
```

```
subjectAltName    MUST NOT be present                        7.1.2.8.2
subject           see 7.1.2.10.2, CA Certificate Naming      7.1.2.8
```

So `e_ext_san_missing` reports the **absence** of an extension this
certificate's own profile forbids it to have, and
`e_subject_common_name_not_from_san` asks its `commonName` to be drawn from
SAN entries the profile forbids it to carry — unsatisfiable rather than merely
inapplicable. The two naming lints read the subscriber clause where § 7.1.2.8
names the CA one.

**The predicate exists, four lines below the one being used.**

```go
util/ca.go:43  func IsSubscriberCert(c) bool { return !IsCACert(c) && !IsSelfSigned(c) }
util/ca.go:50  func IsDelegatedOCSPResponderCert(c) bool { return HasEKU(c, ExtKeyUsageOcspSigning) }
```

A delegated responder is neither a CA nor self-signed, so `IsSubscriberCert`
admits it. Exactly **one** lint in the tree calls
`IsDelegatedOCSPResponderCert` —
`lint_ocsp_id_pkix_ocsp_nocheck_ext_not_included_server_auth.go`. Four lints
on the responder profile exist (`cdp_forbidden`, `cp_forbidden`, `invalid_ku`,
`nocheck`), so the profile is known to the tree; the subscriber lints simply
do not exclude it.

Fix: `&& !util.IsDelegatedOCSPResponderCert(c)` on each of the four, or narrow
`IsSubscriberCert` itself — the latter reaches every lint that uses it, which
is the reason to prefer it.
