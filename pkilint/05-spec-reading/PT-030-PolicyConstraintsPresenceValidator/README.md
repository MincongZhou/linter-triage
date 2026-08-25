# PT-030 — two clauses that describe a scope are reported as ERROR

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `05-spec-reading` — Differing analysis of the normative text |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

Three validators in this file share one shape — an extension is present, the
certificate is not a CA, therefore ERROR:

| validator | code | severity |
|---|---|---|
| `PolicyConstraintsPresenceValidator` | `pkix.end_entity_policy_constraints_extension_present` | ERROR |
| `PolicyMappingsPresenceValidator` | `pkix.end_entity_policy_mappings_extension_present` | ERROR |
| `InhibitAnyPolicyPresenceValidator` | `pkix.end_entity_inhibit_anypolicy_extension_present` | ERROR |

(The third is outside this lane's slice; it is listed because it is the same
shape and the same reading applies.)

None of the three cited clauses states a prohibition:

| clause | what it says |
|---|---|
| § 4.2.1.11 policyConstraints | "The policy constraints extension **can be used** in certificates issued to CAs." |
| § 4.2.1.5 policyMappings | "This extension **is used in** CA certificates." |
| § 4.2.1.14 inhibitAnyPolicy | "The inhibit anyPolicy extension **can be used** in certificates issued to CAs." |

All three are descriptive scope sentences. The MUSTs in those sections are
about something else entirely — § 4.2.1.11's "Conforming CAs MUST NOT issue
certificates where policy constraints is an empty sequence" and "MUST mark
this extension as critical", § 4.2.1.5's "Policies MUST NOT be mapped either
to or from... anyPolicy" — and pkilint reports each of those separately.

**The contrast that settles it is inside the same document.** RFC 5280 §
4.2.1.10 opens:

> The name constraints extension, which **MUST be used only in a CA
> certificate**...

The drafters wrote an explicit prohibition where they wanted one, in the very
next extension along, and pkilint's `pkix.name_constraints_in_ee_certificate`
correctly implements it. For these three they wrote descriptive prose instead.
Reading "is used in CA certificates" as "MUST NOT appear in an EE certificate"
is the reader supplying a normative verb the document withholds.

observed ERROR for an extension whose clause states scope, not obligation
correct no finding, or a notice; the clause supplies no severity

This is the same defect PT-028 records for the Microsoft profile — a clause
whose verb is "may" reported at ERROR — with the difference that here the
clause has no verb of obligation at all.

## What this lane did not verify

- **RFC 4262 is not in `Specs/rfc/`.** `pkix.smime_capabilities_extension_critical` is deferred rather than judged, and its clause's normative word is unread. No claim is made here about whether pkilint's ERROR is right. - The four codes in PT-004 were shown absent from the stock PKIX profile and from all 22 serverauth profiles. The **smime, etsi, CRL and OCSP** profiles were not enumerated — their factories take arguments this lane did not work out. The class being referenced nowhere in the repository is the stronger evidence and does not depend on that gap. - No upstream issue has been filed for any of these.
