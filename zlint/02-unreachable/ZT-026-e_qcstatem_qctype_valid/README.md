# ZT-026 — `e_qcstatem_qctype_valid`'s error path is unreached, and its test asserts nothing

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `02-unreachable` — Checks that cannot fire |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | zlint's own `qctWithWrongType_2024.pem`, with `QcStmtEtsiValidCert11.pem` as the control |

## Upstream issues, adjudicated

- **#461** — Tests failures with Go 1.15 *(closed)*
  **unrelated.** Go 1.15 test failures. Matched incidentally.

## Analysis

The lint is effective in **[2017-11-01, 2023-07-01)** —
`EtsiEn319_412_5_V2_2_1_Date` to `EtsiEn319_411_2_V2_5_0_Date`. Every fixture
written to trip it is dated after that window closed:

| fixture | notBefore | result |
|---|---|---|
| `qctWithWrongType_2024.pem` | 2024-05-01 | `NE` |
| `qctWithWrongType.pem` | 2025-05-01 | `NE` |
| `qctWithEseal.pem` | 2025-05-01 | `NE` |
| `qctWithEsealAndWeb.pem` | 2025-05-01 | `NE` |

**The test that would have caught this compares the wrong field.**
`TestEtsiQcType` declares `ExpectedResult` for seven cases — `lint.Error` for
the 2024 fixture — and then:

```go
result := test.TestLint("e_qcstatem_qctype_valid", tc.InputFilename)

if result.Details != tc.ExpectedDetails {
    t.Errorf("expected result details %v was %v", tc.ExpectedDetails, result.Details)
}
```

`ExpectedDetails` is left at `""` in all seven cases and the lint returns
empty `Details` for `pass`, `NA` and `NE`, so the function passes whatever the
statuses are. `ExpectedResult` is declared and never read.

**A slip, not a convention.** Of the **730** test functions that declare a
`lint.LintStatus` and call `test.TestLint`, this is the **only one** that
never compares a `Status`. The sweep is in the reproduction.

**Note what is *not* wrong here**, because an earlier reading of this got it
backwards. `test.TestLint` does **not** bypass the effective window:
`CertificateLint.execute` calls `CheckEffective` before `Execute`, the test
path and the CLI path are the same, and the six other cases in this same
function — including two expecting `NE` — are correct against the shipped
binary. The defect is one unasserted comparison and four mis-dated fixtures,
not a harness that ignores dates.

Fix: compare `result.Status` against `tc.ExpectedResult`, then re-date the
four `qct*` fixtures inside the window — or, if they are meant to demonstrate
the gate, change their expectations to `NE` and add one dated fixture that
reaches the error branch.
