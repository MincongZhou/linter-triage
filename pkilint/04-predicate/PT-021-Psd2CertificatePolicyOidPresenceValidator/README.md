# PT-021 — `ovr-6.1-3.prohibited_psd2_policy_oid_present` reports the combination OVR-6.1-3 permits

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | `pkilint 0.13.3`, reproduced on a modified corpus certificate |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

`Psd2CertificatePolicyOidPresenceValidator` reports `qcp-web-psd2` on any
certificate pkilint has not typed as a PSD2 certificate:

```python
if (ts_119_495_asn1.qcp_web_psd2 in node.document.policy_oids
        and self._certificate_type not in etsi_constants.PSD2_EIDAS_CERTIFICATE_TYPES):
    raise validation.ValidationFindingEncountered(...)
```

`PSD2_EIDAS_CERTIFICATE_TYPES` is `QEVCP_W_PSD2_EIDAS_CERTIFICATE_TYPES` and
nothing else, and `determine_certificate_type` reaches those four types only
inside `if serverauth_constants.ID_POLICY_EV in policy_oids:`. So the check
requires the **CA/Browser Forum EV** identifier.

> **OVR-6.1-3**: TSPs issuing certificates for EU PSD2 may use the following
> policy identifier to augment the policy requirements associated with policy
> identifier QEVCP-w, **QNCP-w**, or **QNCP-w-gen** as specified in ETSI
> EN 319 411-2.

The validator's own docstring quotes the QNCP-w wording — "to augment the
policy requirements associated with policy identifier QEVCP-w or QNCP-w" — so
this is not staleness against an edition pkilint has not seen: the code
contradicts the sentence written above it. (v1.8.1's change history dates the
QNCP-w addition to **v1.6.1, November 2022**, and QNCP-w-gen to v1.7.1, July
2024; the docstring is at the v1.6.1 wording.)

```
type: QNCP_W_OV_EIDAS_FINAL_CERTIFICATE
  ERROR etsi.ts_119_495.ovr-6.1-3.prohibited_psd2_policy_oid_present
        -- Certificate type is "QNCP_W_OV_EIDAS_FINAL_CERTIFICATE" but PSD2 policy identifier is present
```

The certificate keeps its Open Banking statement and its QNCP-w policy and is
reported for carrying the identifier OVR-6.1-3 says a PSD2 TSP may use to
augment QNCP-w.

**Suggested repair.** Recognise QNCP-w and QNCP-w-gen PSD2 certificate types,
or drop the type test and report only where `qcp-web-psd2` appears with none
of the three policies it is defined to augment.
