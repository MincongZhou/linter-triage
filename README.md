# Certificate linter defects, reproduced

**193 confirmed defects across four linters.**

| tool | entries | with a script | pinned at | tracker read |
|---|---:|---:|---|---|
| [zlint](zlint/) | 94 | 75 | `v3.7.1-20-g1007b1d5` | 2026-08-24 |
| [pkilint](pkilint/) | 39 | 14 | `0.13.3` | 2026-08-24 |
| [x509lint](x509lint/) | 21 | 6 | `103c92f` | 2026-08-24 |
| [certlint](certlint/) | 39 | 15 | `528d78e` | 2026-08-24 |

**110 of 193 ship a runnable `repro.sh`.** The rest were confirmed by reading the pinned source and running the tool by hand; each of those states what it was verified against and what the tool printed, and most name a fixture already in your own tree. A claim about unreachable code is settled by reading it, and packaging a script that demonstrates silence would add nothing.

Each tool directory has its own index, its own contiguous numbering and a `run-all.sh`. Nothing here depends on anything else here.

## How entries are grouped

Ten groups, in five categories:

| category | groups | entries |
|---|---|---:|
| **date-pedantic** | `01-dating` | 31 |
| **lints-not-working** | `02-unreachable`, `03-scope`, `04-predicate` | 103 |
| **parser-unsupported** | `06-parser` | 10 |
| **already-filed-issues** | `00-already-filed` | 11 |
| **other** | `05-spec-reading`, `07-robustness`, `08-hygiene`, `09-absent` | 38 |

| group | | entries |
|---|---|---:|
| `00-already-filed` | Already on your issue tracker | 11 |
| `01-dating` | Requirements applied to certificates that predate them | 31 |
| `02-unreachable` | Checks that cannot fire | 27 |
| `03-scope` | Applied outside the population the clause governs | 10 |
| `04-predicate` | The test itself is wrong | 66 |
| `05-spec-reading` | Differing analysis of the normative text | 8 |
| `06-parser` | Root cause in the decoder, not in the check | 10 |
| `07-robustness` | Panics, run-ending failures, and non-determinism | 7 |
| `08-hygiene` | Descriptions, citations, severities and tests | 20 |
| `09-absent` | A requirement no check covers | 3 |

## Severity

One column, and it is **impact on certificates issued today**: whether a verdict changes on current issuance. It is deliberately not a measure of how alarming the defect is, and it is not frequency.

A check the subject can switch off is serious whether or not anyone has switched it off — so reach is not folded in. **No corpus counts appear anywhere in this package**: a number measured against a corpus you do not have is one you cannot check, and it invites reading frequency as severity.

## Cases

Every entry has `positive/` — the certificate that demonstrates the defect. Where the defect is a *difference*, `negative/` holds the control: the same certificate differing in the one field, which the tool handles correctly. A pair proves the mechanism; a single file only shows output.

`positive/NONE.md` means the reproduction fabricates its input, or the entry is about source the tool never reaches.

## What this package is not

It contains no linter of ours, no path into our tree, and no reference to our own numbering. Every claim is checkable with the tool and the files here.

Entries are `Confirmed` only: each was reproduced against the pinned version before it was numbered, which is why the numbering has no holes. Claims we investigated and disproved are not here, and there are more of those than is comfortable — roughly one in seven did not survive contact with the tool.

See [MISSING-LINTS.md](MISSING-LINTS.md) for requirements **none** of the four tools checks.

