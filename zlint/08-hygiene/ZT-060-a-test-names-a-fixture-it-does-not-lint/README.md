# ZT-060 — a test names a fixture it does not lint

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `08-hygiene` — Descriptions, citations, severities and tests |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool |
| **Cases** | positive/ |
| **Verified against** | fixture `dsaCorrectOrderInSubgroup.pem` |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

`TestDSANotCorrectOrderSubgroup` sets `inputPath :=
"dsaCorrectOrderInSubgroup.pem"` and `expected := lint.Error`, loads that
file, mutates the parsed certificate in Go, and lints the mutation. The same
file under `TestDSACorrectOrderSubgroup` is `lint.Pass`, and the binary
agrees. The test states an expectation beside a filename that does not produce
it.

`test.TestLintCert` is documented upstream as intentional, so the helper is
not the defect — the defect is that the mutated case is labelled with the
unmutated file's name and the mutated bytes exist nowhere. Three call sites;
16 for `TestLintWithConfig`, which has a milder version of the same problem.

This matters to anyone mining the tests for ground truth, which is the only
machine-readable expectation any vendored linter supplies.

Fix: serialise the mutation to `testdata/` and lint it by filename.
