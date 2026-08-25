# PT-022 — `gen-5.2.1-3.invalid_psd_organization_id_format` reports the alternative GEN-5.2.1-4 provides, at error level

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

`PsdOrganizationIdentifierFormatValidator` matches every
`organizationIdentifier` on a PSD2 certificate against one regular expression
and reports anything else at ERROR:

```python
_PSD_ORGID_FORMAT_REGEX = re.compile("^PSD[A-Z]{2}-[A-Z]{2,8}-.+$")
...
if m is None:
    raise validation.ValidationFindingEncountered(
        self.VALIDATION_INVALID_PSD_ORGANIZATION_ID_FORMAT, ...)
```

TS 119 495 § 5.2.1 states two things the check does not carry.

**GEN-5.2.1-3 says "should", not "shall"** — "the subject
organizationIdentifier attribute **should** contain the Authorization Number
encoded using the following structure". The validator's own docstring quotes
the sentence with the word in it.

**GEN-5.2.1-4 provides for the other case in as many words**:

> If the encoding is not as defined in GEN 5.2.1-3 above another form of
> identity type shall be carried in organizationIdentifier encoded using the
> syntax identified by the legal person semantics identifier as defined in
> ETSI EN 319 412-1, clause 5.1.4.

So a PSD2 certificate carrying a VAT, NTR or LEI identifier under EN 319
412-1's legal person syntax is doing what the clause immediately below the
cited one requires, and pkilint reports it as an error.

```python
# ... load the certificate as in PT-021, then, before re-encoding:
from pyasn1.type import char
for rdn in cert_asn1["tbsCertificate"]["subject"]["rdnSequence"]:
    for atv in rdn:
        if str(atv["type"]) == "2.5.4.97":
            atv["value"] = enc(char.UTF8String("VATLT-123456789"))
```

```
type: QEVCP_W_PSD2_EIDAS_FINAL_CERTIFICATE
   ERROR etsi.ts_119_495.gen-5.2.1-3.invalid_psd_organization_id_format
         -- Invalid PSD organization identifier format: "VATLT-123456789"
```

The certificate's original value was `PSDCZ-CNB-64948242`; one attribute is
all that changed.

**Severity.** Medium: an error-level false positive on a shape the document
names, not yet reproduced on an unmodified certificate.

**Suggested repair.** Two changes.

## What was not verified
