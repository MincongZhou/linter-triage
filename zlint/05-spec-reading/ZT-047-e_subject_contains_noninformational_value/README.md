# ZT-047 — `e_subject_contains_noninformational_value` enforces a clause against the attribute that clause excepts

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `05-spec-reading` — Differing analysis of the normative text |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | three real certificates from one issuance line |

## Upstream issues, adjudicated

- **#863** — Lint for CABF SMIME 7.1.4.2.2.a and 7.1.4.2.2.e - If present, Subject name fields must not contain placeholder data *(open)*
  **unrelated.** A feature request for an S/MIME placeholder-data lint. This entry is a false positive on the organizationalUnitName the clause excepts.

## Analysis

The lint's own block comment reproduces the clause it enforces:

```
BRs: 7.1.4.2.2
With the exception of the subject:organizationalUnitName (OU) attribute,
optional attributes, when present within the subject field, MUST contain
information that has been verified by the CA. Metadata such as '.', '-', and
' ' (i.e. space) characters, and/or any other indication that the value is
absent, incomplete, or not applicable, SHALL NOT be used.
```

That paragraph is **BR 1.0 § 9.2.6**, word for word, and BR 1.0 is the only
version that ever carried the OU exception. BR 1.0 was effective 2012-07-01,
which is exactly `util.CABEffectiveDate`, so the lint's start date is right.
What is wrong is that it enforces the paragraph against the one attribute the
paragraph excludes, for as long as BR 1.0 was the version in force.

BR 1.1.0, effective 2012-09-14, split the section: § 9.2.6 for OU — a process
preventing OU from naming a natural person or Legal Entity, a different and
narrower requirement — and § 9.2.7 for everything else. The exception phrase
does not survive the split, so from 2012-09-14 the lint is correct about OU.

Three real certificates from the same issuance line, all carrying `OU=-` and
no other metadata-only attribute, so the date is the only thing that differs:

| notBefore | version in force | zlint |
|---|---|---|
| 2012-06-19 | none | `NE` |
| 2012-08-16 | BR 1.0 | **`error`** |
| 2012-09-18 | BR 1.1.0 | `error`, correctly |

Fix: skip `organizationalUnitName` when `notBefore` is earlier than
2012-09-14. The other attributes carry the requirement from 2012-07-01 and
need no change.

`brhistory.py` reported "102 of 102 versions match, earliest 1.1.0", which is
indistinguishable from a clause that genuinely began there. The BR 1.0 PDF is
at `cabforum.org/uploads/Baseline_Requirements_V1.pdf`, unlinked from the
archive page; it is now `br-1.0.0.pdf` and the series is 103.
