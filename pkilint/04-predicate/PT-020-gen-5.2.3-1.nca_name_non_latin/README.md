# PT-020 — `gen-5.2.3-1.nca_name_non_latin` tests ASCII, not the Latin alphabet

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | `pkilint 0.13.3`, reproduced on corpus certificates |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

`NCANameLatinCharactersValidator` (`pkilint/etsi/ts_119_495.py`) cites
GEN-5.2.3-1 in its own docstring —

> The NCAName shall be plain text using Latin alphabet provided by the
> Competent Authority itself for purpose of identification in certificates.

```python
if not nca_name.isascii():
    raise validation.ValidationFindingEncountered(
        self.VALIDATION_NCA_NAME_NON_LATIN, f"invalid NCA name: {nca_name}")
```

`str.isascii` is neither of the clause's two conditions, and it is wrong in
both directions:

- **The Latin alphabet is larger than ASCII.** *Österreich*, *Ελλάδος*'s neighbours in the register — *Autorité de contrôle prudentiel et de résolution*, *Česká národní banka*, *Magyar Nemzeti Bank* — are Latin-script names whose diacritics leave the ASCII range. The clause asks for the name "provided by the Competent Authority itself", which is precisely the form that carries them. - **`isascii` accepts what is not plain text.** A name made of `U+0000` and `U+001B` passes it.

```
$ ~/.venv/linters/bin/python3 runetsi.py \
    
== bug1972887-crtsh19096238066.der type: QNCP_W_GEN_LEGAL_PERSON_EIDAS_FINAL_CERTIFICATE
    ERROR etsi.ts_119_495.gen-5.2.3-1.nca_name_non_latin
          -- invalid NCA name: Finanzmarktaufsicht Österreich
```

**Severity.** Medium: an error-level false positive on conformant certificates
from a supervised European CA, reproducible today, but confined to authorities
whose names carry diacritics.
