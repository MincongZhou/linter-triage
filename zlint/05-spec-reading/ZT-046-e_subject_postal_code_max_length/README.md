# ZT-046 — `e_subject_postal_code_max_length` bounds a DN attribute with an X.400 constant

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `05-spec-reading` — Differing analysis of the normative text |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl, python3 |
| **Cases** | positive/ |
| **Verified against** | real certificates |

## Upstream issues, adjudicated

- **#762** — Address inconsistencies between RFC5280 and CABF BRs/X.520 *(open)*
  **related.** Same symptom, different mechanism, and the mechanisms disagree. #762 assumes RFC 5280 sets the bound at 16 and asks for a way to prefer the CABF/X.520 40. This entry says the 16 comes from ub-postal-code-length, which bounds something else -- so the RFC premise of #762 may itself be wrong.

## Analysis

The lint reads `c.Subject.PostalCode` — the Subject DN attribute
`id-at-postalCode`, 2.5.4.17 — and faults it above 16 characters, citing RFC
5280 Appendix A.1 and carrying `ub-postal-code-length INTEGER ::= 16` as its
own comment.

That constant is real and bounds something else. In Appendix A.1 it appears in

```
PostalCode ::= CHOICE {
   numeric-code   NumericString (SIZE (1..ub-postal-code-length)),
   printable-code PrintableString (SIZE (1..ub-postal-code-length)) }
```

— the X.400 postal-delivery OR-address type, among `ub-pds-name-length` and
`ub-pds-parameter-length` in the 1988-syntax module. It has nothing to do with
the Subject DN.

**RFC 5280 defines no `X520PostalCode`**, so the document the lint cites states no bound for the attribute it reads. The governing bound is ITU-T X.520's `ub-postal-code` = 40, which is what the Baseline Requirements' own § 7.1.4.2 table cites: `| postalCode | 2.5.4.17 | X.520 | … | 40 |`.

The sibling `e_subject_street_address_max_length` cites X.520 directly and
gets 128 right, so this is a slip in one lint rather than a house reading.
