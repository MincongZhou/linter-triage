# ZT-090 — `w_sub_cert_aia_contains_internal_names` cites a clause that says nothing about internal names

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `08-hygiene` — Descriptions, citations, severities and tests |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | document-only reproduction |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```go
/************************************************************************
BRs: 7.1.2.10.3
CA Certificate Authority Information Access
This extension MAY be present. If present, it MUST NOT be marked critical, and it MUST contain the
HTTP URL of the CA's CRL service.

id-ad-ocsp        A HTTP URL of the Issuing CA's OCSP responder.
id-ad-caIssuers   A HTTP URL of the Issuing CA's Certificate.
*************************************************************************/
```

That is the lint's own banner comment. The registered lint reads:

```go
Name:        "w_sub_cert_aia_contains_internal_names",
Description: "Subscriber certificates authorityInformationAccess extension \
              should contain the HTTP URL of the issuing CA's certificate, \
              for public certificates this should not be an internal name",
Citation:    "BRs: 7.1.2.10.3",
```

**§7.1.2.10.3 is the *CA Certificate* Authority Information Access clause**,
not the subscriber one — and even read as a typo for the subscriber clause it
governs (§7.1.2.7.7, confirmed directly against
`Policies/Cert-BR-Baseline.md`), neither section says anything about internal
names. §7.1.2.10.3's own table permits `id-ad-ocsp` and `id-ad-caIssuers`,
each `MAY`, and says nothing about the *host* either accessMethod names.
§7.1.2.7.7 states the same shape of table for subscriber certificates and is
equally silent on host form.

**"Internal Name" is a defined term scoped away from this field.**
`Policies/Cert-BR-Baseline.md`'s Definitions section: "A string of characters
(not an IP address) in a **Common Name or Subject Alternative Name field** of
a Certificate that cannot be verified as globally unique within the public
DNS..." An AIA `accessLocation` is neither field.

**observed**: the lint fires a warning citing BR §7.1.2.10.3 whenever an AIA
accessMethod's host is not a registered public TLD. **correct**: neither
§7.1.2.10.3 nor the subscriber AIA clause it should probably have cited
(§7.1.2.7.7) states any such restriction, in any published edition consulted.

**mechanism**: as with the S/MIME sibling, the check's own banner comment does
not support what `Execute` tests — it quotes a CRL-service sentence (itself
likely copy-pasted from a neighbouring clause; no version of §7.1.2.10.3
mentions a CRL service) and the `HasValidTLD` call answers a question neither
the quoted text nor the section it numbers ever raises.

**fix**: either drop the citation and file the check as a `Community` lint
(zlint's own guide names this category for exactly this situation), or find
and cite whatever document actually imposes a host-form restriction on an AIA
accessLocation, if one exists.

The underlying practice (host-form validation on an AIA accessLocation) is a
`community`-shelf candidate, matching the S/MIME sibling's disposition — this
project already has that shelf, so no new one is needed — but deciding to add
it is a scope call beyond one lane's eight-site assignment; see
`MANIFEST.md`'s open questions.

**The `HasValidTLD(purl.Hostname, time.Now)` question, settled.** The
assignment for this lane named this as the second of two `time.Now` call sites
(the other being the `cabf_smime_br` sibling `ZT-092` examined) and asked
whether it is a design or a slip, as distinct from the two `c.NotBefore` call
sites in `lint_dnsname_right_label_valid_tld.go`. **It is a design, not a
slip**: both `time.Now` sites are identical in shape and in the question they
ask (does this AIA host resolve under a *currently* delegated TLD, since a
relying party might dereference the URL today), which is a coherent, if
debatable, reading distinct from the SAN/CN sites' question (was this name a
legitimate identity claim *at issuance*). Two identical call sites is the
contract's own signal for "design, not slip." This does not settle whether the
design is a *good* one — a non-reproducible warning is a poor way to test
liveness, and the underlying citation defect above means the question is moot
for this lint regardless — but the two sites are not an accident of copying.
