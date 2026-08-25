# ZT-064 — `w_qcstatem_qcpds_lang_case` returns Error, which its own name denies

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `08-hygiene` — Descriptions, citations, severities and tests |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool |
| **Cases** | positive/ and negative/ |
| **Verified against** | zlint's own fixtures, unmodified |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

zlint's contributor guide states the rule this breaks: *"Lints only return one
non-success or non-fatal status, which must also match their name prefix."*
`Execute` returns two.

```go
if len(errString) == 0 {
        if len(wrnString) == 0 { return ...Pass }
        else { return &lint.LintResult{Status: lint.Warn,  Details: wrnString} }
} else {
        return &lint.LintResult{Status: lint.Error, Details: errString}
}
```

`wrnString` is the lint's subject — a PDS language code that is not all
lower-case. **`errString` is not**: it is
`util.ParseQcStatem(...).GetErrorInfo`, a decoding failure of the
`qcStatements` extension, and `e_qcstatem_qcpds_valid` reports the identical
string on the identical certificate under a name that fits it.

**Low.** The certificate is condemned either way and correctly — its
`qcStatements` really is malformed — so no verdict is falsified. What is wrong
is where the finding is filed: a consumer selecting lints by prefix is handed
an error by a warning, and a reader is told a letter-case check failed when
the extension did not decode.

Fix: return `Pass` when `errString` is non-empty and leave the encoding to
`e_qcstatem_qcpds_valid`. Renaming the lint `e_` and dropping the `Warn`
branch would also satisfy the guide, but the control shows the `Warn` branch
is reachable and right, so the first is the smaller change.
