# ZT-092 — `w_smime_aia_contains_internal_names` cites a clause that says nothing about internal names

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
BRs: 7.1.2.3c
CA Certificate Authority Information Access
The authorityInformationAccess extension MAY contain one or more
accessMethod values for each of the following types:

id-ad-ocsp        specifies the URI of the Issuing CA's OCSP responder.
id-ad-caIssuers   specifies the URI of the Issuing CA's Certificate.

*************************************************************************/
```

That is the lint's own banner comment, quoting the clause it cites. The check
it registers reads:

```go
Name:        "w_smime_aia_contains_internal_names",
Description: "SMIME certificates authorityInformationAccess. Internal domain
              names should not be included.",
Citation:    "BRs: 7.1.2.3c",
```

**§7.1.2.3.c of the S/MIME Baseline Requirements does not mention internal
domain names.** Read in full from the archive (`Specs`/`Policies` mirrors of
`smime-br-1.0.0.txt` through `smime-br-1.0.15.txt`, the full published run),
the clause says only that `authorityInformationAccess` SHOULD be present,
SHALL NOT be marked critical, and states a permitted-URI-scheme table (HTTP
required, under Strict/Multipurpose/Legacy) for each of `id-ad-ocsp` and
`id-ad-caIssuers`. Nothing in it, or anywhere else the document's own text was
searched, restricts the *host* named by either accessMethod.

**The term itself does not occur in the document.** `grep -i "internal name"`
across all sixteen published editions (`smime-br-1.0.0.txt` through
`smime-br-1.0.15.txt`) returns nothing. "Internal Name" is a defined term in
the *TLS* Baseline Requirements (`Policies/Cert-BR-Baseline.md`, the
Definitions section: "a domain name that does not end with a Top-Level Domain
registered in IANA's Root Zone Database"), applied there to a Common Name or
`subjectAltName` entry — not to an AIA accessMethod, and not incorporated by
reference into the S/MIME BR. §1.6.1 of the S/MIME BR incorporates only the
CA/Browser Forum Network and Certificate System Security Requirements'
definitions "as if fully set forth herein"; the TLS BR is referenced elsewhere
by name (as "TLS Baseline Requirements") but its clauses are not pulled in
wholesale.

**observed**: the lint fires a warning citing S/MIME BR §7.1.2.3.c whenever an
AIA accessMethod's host is not a registered public TLD. **correct**:
§7.1.2.3.c imposes no such requirement, in any published edition.

**mechanism**: the check's own banner comment (quoted above, taken verbatim
from the lint's source) does not support what `Execute` tests either — it
quotes only the presence/accessMethod-type sentence, and the `HasValidTLD`
call it goes on to make answers a question the quoted text never raises. This
is not a case of two documents disagreeing or of a scope decision; the cited
document does not state the rule at all.

**fix**: either drop the citation to §7.1.2.3.c and file the check as a
`Community` lint (no governing document — zlint's own guide states this
category explicitly for exactly this situation), or find and cite whatever
document actually does impose the restriction, if one exists.

Filing this under `cabf_smime_br` while citing a clause that does not impose
the finding would be exactly the defect that check exists to catch.

Left to whoever picks up the `community` question above.
