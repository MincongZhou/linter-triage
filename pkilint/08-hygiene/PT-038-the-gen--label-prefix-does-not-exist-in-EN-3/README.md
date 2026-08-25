# PT-038 — the `gen-` label prefix does not exist in EN 319 412-5, and two TS 119 495 citations name clauses that are not there

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `08-hygiene` — Descriptions, citations, severities and tests |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | `pkilint 0.13.3`, read from the source and every published edition |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

Ten of the eleven finding codes in `pkilint/etsi/en_319_412_5.py` are built
from a `gen-<clause>` prefix:

```
etsi.en_319_412_5.gen-4.2.4.iso_country_code_list_empty
etsi.en_319_412_5.gen-4.2.4.iso_country_code_invalid
etsi.en_319_412_5.gen-4.2.3.qc_type_mismatch
etsi.en_319_412_5.gen-4.3.2.currency_code_invalid
etsi.en_319_412_5.gen-4.3.2.discouraged_numeric_currency_code_present
etsi.en_319_412_5.gen-4.3.2.amount_negative
etsi.en_319_412_5.gen-4.3.2.exponent_negative
etsi.en_319_412_5.gen-4.3.3.retention_period_years_not_positive
etsi.en_319_412_5.gen-4.3.4.iso_language_code_invalid
etsi.en_319_412_5.gen-4.3.4.url_scheme_not_https
```

**EN 319 412-5 has never used a `GEN-` label.** Its numbered requirements are
`QCS-`, and they first appear in v2.4.1:

```
$ cd Specs/etsi
$ for v in v1.1.1 v2.1.1 v2.2.1 v2.3.1 v2.4.1 v2.5.1 v2.6.1; do
    printf '%s GEN-=%s QCS-=%s\n' "$v" \
      "$(grep -c 'GEN-' "EN 319 412-5 $v.txt")" \
      "$(grep -c 'QCS-' "EN 319 412-5 $v.txt")"
  done
v1.1.1 GEN-=0 QCS-=0
v2.1.1 GEN-=0 QCS-=0
v2.2.1 GEN-=0 QCS-=0
v2.3.1 GEN-=0 QCS-=0
v2.4.1 GEN-=0 QCS-=12
v2.5.1 GEN-=0 QCS-=15
v2.6.1 GEN-=0 QCS-=16
```

`GEN-` is **EN 319 412-2**'s prefix, which is where the same file's eleventh
code correctly does not go: `qcs-4.1-02.qcstatements_extension_is_critical` is
the one code in the file that cites a label the document actually carries.

The clause *numbers* are right in every case, so a reader who ignores the
prefix finds the requirement. What the prefix costs is a reader who searches
the document for `GEN-4.3.2` and concludes the check cites nothing.

Two codes in `pkilint/etsi/ts_119_495.py` name clause numbers that are not in
the document either:

| code | document's label |
|---|---|
| `gen-5.1.1.qc_eu_pds_missing` | GEN-5.1-1 (clause 5.1; there is no clause 5.1.1) |
| `gen-5.2-2.invalid_psp_role` | GEN-5.2.2-3 (role *name*) |
| `gen-5.2-2.invalid_psp_oid` | GEN-5.2.2-2 (role *identifier*) |
| `gen-5.2.2-5.psp_role_mismatch` | REG-5.2.2-5, not GEN- |

The last is edition-dependent and the least certain of the four: v1.8.1 labels
it `REG-`, and whether an earlier edition wrote `GEN-` cannot be checked,
since only v1.8.1 is held.

**Severity.** Low. No verdict changes; the codes mislead a reader looking the
citation up. This is the same shape as `PT-037` and, like it, a finding code
is part of pkilint's published interface, so the fix is a rename somebody has
to schedule rather than a patch.

**Suggested repair.** Rewrite the classifier prefix in
`pkilint/etsi/en_319_412_5.py` from `gen-` to `qcs-` and correct the four TS
119 495 clause numbers above.
