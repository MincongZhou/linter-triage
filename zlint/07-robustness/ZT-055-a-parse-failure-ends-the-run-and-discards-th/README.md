# ZT-055 — a parse failure ends the run and discards the queue

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `07-robustness` — Panics, run-ending failures, and non-determinism |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool |
| **Cases** | positive/ |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

| invocation | result |
|---|---|
| bad file alone | non-zero exit, 0 bytes stdout, `level=fatal` |
| missing file | non-zero exit, `level=fatal` — **indistinguishable** |
| bad file, then good file | 0 bytes; the good certificate is never linted |
| good file, then bad file | output, then the process dies |

The failure is `log.Fatal`, so one unparseable input terminates a multi-file
run and discards every file queued behind it. A consumer parsing stdout sees
nothing; one checking the exit code cannot tell a malformed certificate from a
bad path.

7 of certificates are refused this way.

Fix: emit a JSON entry per input naming the parse failure, and continue.
