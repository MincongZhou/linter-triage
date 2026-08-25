# PT-007 — `gen-5.1.1.qc_eu_pds_missing` can never be reported

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `02-unreachable` — Checks that cannot fire |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | `pkilint 0.13.3`, reproduced on a corpus certificate |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

`PresenceofQCEUPDSStatementValidator` (`pkilint/etsi/ts_119_495.py`) reports a
certificate whose `qcStatements` does not name the Open Banking statement:

```python
if (ts_119_495_asn1.id_etsi_psd2_qcStatement
        not in node.document.qualified_statement_ids):
    raise validation.ValidationFindingEncountered(self.VALIDATION_QC_EU_PDS_MISSING)
```

`pkilint/etsi/__init__.py` installs it on one set of certificate types:

```python
if certificate_type in etsi_constants.QEVCP_W_PSD2_EIDAS_CERTIFICATE_TYPES:
    qc_statement_validators.append(ts_119_495.PresenceofQCEUPDSStatementValidator())
```

and `determine_certificate_type` reaches those four types only through

```python
is_psd2 = ts_119_495_asn1.id_etsi_psd2_qcStatement in qualified_statement_ids
if is_psd2:
    return CertificateType.QEVCP_W_PSD2_EIDAS_PRE_CERTIFICATE if is_precert else ...
```

The installation condition is the predicate's exact negation. A certificate
without the statement is never routed to the validator; a certificate routed
to it always has the statement.

**Reproduction** — run under the interpreter pkilint is installed into:

```
1. FIRES: etsi.ts_119_495.gen-5.1.1.qc_eu_pds_missing
2. QCP_N_QSCD_EIDAS_FINAL_CERTIFICATE PSD2 type? False
3. no finding on QEVCP_W_PSD2_EIDAS_PRE_CERTIFICATE
```

A structural check agrees: iterating every `CertificateType` and walking the
validator tree, the validator is installed on exactly the four
`PSD2_EIDAS_CERTIFICATE_TYPES` and no others.

**Severity.** Medium rather than High. The requirement is real — GEN-5.3-2 and
GEN-5.4-2 both say the Open Banking QCStatement "shall be included in the
certificate" — and it is wholly unreported, but the shape does not occur : 0
of certificates assert `qcp-web-psd2` and omit the statement, so nothing here
is being passed clean that should not be.

**Suggested repair.** Trigger on the policy identifier instead.
