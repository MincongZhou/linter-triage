# ZT-029 — three `e_sub_cert_*` lints hold CA certificates to the Subscriber profile

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `03-scope` — Applied outside the population the clause governs |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ |
| **Verified against** | two real trust-store intermediates, one zlint fixture |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

Observed `error` from a Subscriber Certificate lint on a subordinate CA;
correct `NA`.

```go
// lint_sub_cert_crl_distribution_points_does_not_contain_url.go
return util.IsExtInCert(c, util.CrlDistOID)
// lint_sub_ca_crl_distribution_points_does_not_contain_url.go
return util.IsSubCA(c) && util.IsExtInCert(c, util.CrlDistOID)

// lint_sub_cert_crl_distribution_points_marked_critical.go
return util.IsExtInCert(c, util.CrlDistOID)
// lint_sub_ca_crl_distribution_points_marked_critical.go
return util.IsSubCA(c) && util.IsExtInCert(c, util.CrlDistOID)

// lint_sub_cert_eku_server_auth_client_auth_missing.go
return c.ExtKeyUsage != nil
```

Two of anything is a design, and the guarded halves of those two pairs settle
what the design is. Each unguarded lint carries "Subscriber certificate" in
its own `Name` and `Description` and cites BRs 7.1.2.3, which is headed
"Subscriber Certificate". The clause next door states different requirements
for the same extension — BR 1.8.7, the version in force for most of the
window:

> **7.1.2.2 Subordinate CA Certificate** — b. cRLDistributionPoints — This
> extension MUST be present and MUST NOT be marked critical.
>
> **7.1.2.3 Subscriber Certificate** — b. cRLDistributionPoints — This
> extension MAY be present. If present, it MUST NOT be marked critical.

and §7.1.2.2(g) makes `extKeyUsage` optional for a subordinate CA, with a
different permitted set, rather than requiring either authentication purpose.
This is [ZT-001](#zl-020)'s shape; those six were the `subjectAltName`
name-type lints, and these three are the rest of it.

| lint | firings | on CA certificates |
|---|---:|---:|
| `e_sub_cert_crl_distribution_points_does_not_contain_url` | 90 | 25 |
| `e_sub_cert_eku_server_auth_client_auth_missing` | 15 | 6 |
| `e_sub_cert_crl_distribution_points_marked_critical` | 10 | 5 |

36 CA certificates. The two `e_sub_ca_*` siblings fire 23 and 5 times and
every one of those firings is a certificate the unguarded lint has already
reported, so 28 of the 36 are duplicates and 8 are findings no correctly
scoped lint makes. One of zlint's own fixtures, `subCAWcrlDistCrit.pem`, was
written for the sub-CA lint and draws both.

Two of the 25 under the first lint are root CAs, which `util.IsSubCA`
excludes, so the guard alone would leave those two unreported. BR §7.1.2.11.2
states the http requirement of any `cRLDistributionPoints` that is present,
whatever the profile, so the end state wants a guard plus a third lint — or
one lint named for the clause rather than for one profile.

Fix: `util.IsSubscriberCert(c) &&` in front of each of the three
`CheckApplies` bodies.
