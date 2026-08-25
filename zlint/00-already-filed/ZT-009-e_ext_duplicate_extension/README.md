# ZT-009 — `e_ext_duplicate_extension` joins unsorted map keys into its details

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `00-already-filed` — Already on your issue tracker |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, python3 |
| **Cases** | positive/ |
| **Verified against** | zlint's own `multDupeExts.pem` |
| **Would otherwise sit in** | see the adjudication below |

## Upstream issues, adjudicated

- **#549** — Update e_ext_duplicate_extension error result with Details message. *(closed)*
  **follow-up.** #549 asked for the Details message and was fixed in 2021. This entry is about that message: the OIDs it joins come out of a map unsorted.

## Analysis

`lints/rfc/lint_ext_duplicate_extension.go`:

```go
// If there were duplicates turn the map keys into a list so we
// can join them for the details string.
var duplicateOIDsList []string
for oid := range duplicateOIDs {                 // a map: random order
	duplicateOIDsList = append(duplicateOIDsList, oid)
}
…
Details: "The following extensions are duplicated: " +
         strings.Join(duplicateOIDsList, ", "),
```

The list exists only to be joined — the comment says so — and is never sorted.
Forty runs over zlint's own `multDupeExts.pem` produce both orderings of
`2.5.29.14, 2.5.29.35`, with `"result":"error"` every time.

Same root cause as [ZT-057](#zl-059), a different function, so fixing that one
does not touch this. Filed separately for that reason.

**Fix**: `sort.Strings(duplicateOIDsList)` before the `Join`.
