# PT-028 — a clause that says "may" is reported as an ERROR

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `05-spec-reading` — Differing analysis of the normative text |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ |
| **Verified against** | `pkilint./repro.sh` (the validator's own source, plus one certificate carrying neither extension) |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

Microsoft's Trusted Root Program Requirements state two obligations in one
sentence, at "3. Program Technical Requirements" -> "A. Root Requirements",
item 5:

> All issuing CA certificates **must** contain either a CDP extension with a
> valid CRL and/or an AIA extension to an OCSP responder. An end-entity
> certificate **may** contain either an AIA extension with a valid OCSP URL
> and/or a CDP extension pointing to a valid HTTP endpoint containing the CRL.
> If an AIA extension with a valid OCSP URL is NOT included, then the resulting
> CRL File **should** be <10MB.

Three normative verbs, three different strengths, one sentence. pkilint
implements the second one and reports it at ERROR:

```python
class EndEntityRevocationInformationPresenceValidator(validation.Validator):
    """
    Microsoft Root Program Requirements, 3.A.5:

    An end-entity certificate may contain either an AIA extension with a valid
    OCSP URL and/or a CDP extension pointing to a valid HTTP endpoint
    containing the CRL.
    """

    VALIDATION_REVOCATION_INFORMATION_ABSENT = validation.ValidationFinding(
        validation.ValidationFindingSeverity.ERROR,
        "msft.end_entity.revocation_information_absent",
    )
```

The docstring is the clause, quoted correctly, with its "may" intact. The line
below it declares ERROR. Nothing else in the file narrows the population or
adds a condition the clause does not have: the validator fires whenever an
end-entity certificate carries neither an http OCSP responder nor an http CRL
distribution point.

observed msft.end_entity.revocation_information_absent at ERROR correct no
finding — 3.A.5 permits an end-entity certificate to carry revocation
information and does not require it

This is the check contradicting **its own citation**, which is the test in
[README.md](README.md): the behaviour has to match what the check claims, and
here the claim is printed three lines above the severity that breaks it.

**The control is in the same output.** On the reproduction certificate
`cabf.serverauth.subscriber.revocation_information_absent` fires too, and that
one is right — the CA/Browser Forum does require revocation information of a
subscriber certificate. The Microsoft code adds a second ERROR beside it for a
clause that permits what it reports. Two findings, one defect, and only one of
them cites a requirement.

**The numbering is pkilint's, and it is correct.** The docstring says 3.A.5
and the document agrees: its own Note under "C. Revocation Requirements" cites
"section 3.C.3", which fixes the scheme. There is no section 3.1.10 in the
document; a rule in this tree cited one until 2026-08-22 and was wrong to.

**The mandatory half is unimplemented, and mostly does not need
implementing.** No `msft.*` code covers the first sentence. A certificate can
breach it only by carrying neither extension, and for a subordinate CA that is
already `cabf.serverauth.ca.crl_distribution_points_extension_absent`.

**A fix.** Drop the validator, or demote it. pkilint has INFO and NOTICE, and
"this end-entity certificate carries no revocation information" is a
reasonable thing to say at either. It cannot be an ERROR, because no
requirement is broken.
