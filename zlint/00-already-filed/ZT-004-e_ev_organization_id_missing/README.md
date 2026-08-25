# ZT-004 — `e_ev_organization_id_missing` holds Subordinate CAs to the EV Subscriber profile

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `00-already-filed` — Already on your issue tracker |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ |
| **Verified against** | the certificate a Problem Report was filed against |
| **Would otherwise sit in** | see the adjudication below |

## Upstream issues, adjudicated

- **#1005** — lint_ev_organization_id_missing incorrectly flags CA certificates without cabfOrganizationIdentifier *(open)*
  **duplicate.** Same claim: the EV Subscriber requirement applied to CA certificates. Open, with a third party asking for a ruling.

## Analysis

Observed `error` on a Subordinate CA certificate; correct `NA`. The lint
registers no role predicate, so any certificate asserting an EV policy and
naming `subject:organizationIdentifier` satisfies it, CA or not.

EV Guidelines §7.1.2 is the Subscriber Certificate profile; EV CA certificates
are profiled in §7.1.4.3, which states no such condition. **This is not a
reading of ours.** The question was put to the CA/Browser Forum by an EU
conformity assessment body and answered by the Chair on 2026-02-09:

> The requirements for the presence and contents of extensions in EV CA
> certificates are indicated in section 7.1.4.3. The requirements for
> extensions in section 7.1.2 (where the OrgId extension is listed alongside
> the SAN extension) are applicable only to Subscriber Certificates.

A Certificate Problem Report advancing the opposite reading — that a SubCA
operating under the EVG and carrying an `organizationIdentifier` must also
carry `cabfOrganizationIdentifier` — was filed against `DigiCert QuoVadis G3
Qualified TLS RSA4096 SHA256 2023 CA1` and closed as invalid on that basis.
Mozilla Bugzilla 2056663, July 2026. That certificate is the reproduction
here, and zlint reports it.

Nothing here claims the report was produced by zlint. What is claimed is that
the lint encodes the reading the Forum rejected, and that a CA acting on its
output would be repairing a requirement that does not apply.

Severity is High rather than Medium because the finding is actionable in the
wrong direction: it names a real, checkable defect on a certificate that has
none, in a population that cannot be reissued without redistribution.

Fix: gate `CheckApplies` on the certificate being a Subscriber Certificate, as
the lints implementing the rest of §7.1.2 do.
