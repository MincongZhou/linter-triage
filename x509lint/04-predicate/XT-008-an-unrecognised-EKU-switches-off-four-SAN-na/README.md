# XT-008 — an unrecognised EKU switches off four SAN name-type prohibitions

| | |
|---|---|
| **Tool** | `kroeckx/x509lint` at `103c92f` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ |
| **Verified against** | fabricated pair differing in one byte |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```
EKU = 1.3.6.1.5.5.7.3.3  (codeSigning)      E: Invalid type in SAN entry
EKU = 1.3.6.1.5.5.7.3.99 (unassigned)       W: Unknown extended key usage
```

Same SAN — a single `otherName` — same subject, same everything. The two DERs
differ in one content octet of the EKU OID.

`CheckSAN` relaxes `GEN_OTHERNAME`, `GEN_X400`, `GEN_EDIPARTY` and `GEN_URI`
when `WARN_UNKNOWN_EKU` is set, and that flag is set by the `else` arm of the
EKU classification loop in `CheckEKU` — by any OID absent from x509lint's
eight-entry table. Ordering confirmed by reading the call sites, not inferred:
`CheckEKU` runs at `checks.c:2279`, `CheckSAN` at `2281`, so the flag is set
before it is consulted.

Appending one unassigned OID to a non-serverAuth certificate therefore removes
four SAN errors. Conversely a certificate whose EKUs x509lint *does* recognise
gets `ERR_INVALID_SAN_TYPE` for name types the governing document permits — an
S/MIME certificate carrying `id-on-SmtpUTF8Mailbox`, which is an `otherName`,
is flagged unless it happens to carry an OID x509lint has never heard of.

The comment in the source states the rule and the implementation is faithful
to it, so this is not a coding slip. The rule itself is the defect: everything
in `name_type_allowed[]` starts forbidden and is enabled by a positive
assertion the certificate makes; this is the sole branch where the default
flips permissive, and it flips on x509lint *not recognising* something.

Fix: gate on a positive statement about the certificate's purpose, not on the
absence of one from the linter's table.
