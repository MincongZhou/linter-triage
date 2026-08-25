# ZT-057 — `GetKeyUsageStrings` ranges over a map, so two lints print non-deterministic details

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `07-robustness` — Panics, run-ending failures, and non-determinism |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | none of its own |
| **Verified against** | reuses ZT-005's `serverauth-all-three-listed-bits.pem` |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```go
func GetKeyUsageStrings(keyUsages x509.KeyUsage) []string {
	var keyUsageStrings []string
	for ku, name := range KeyUsageToString {          // a map
		if KeyUsageIsPresent(keyUsages, ku) {
			keyUsageStrings = append(keyUsageStrings, ...)
```

Go randomises map iteration order deliberately, so the slice comes back in a
fresh order on every call. It goes straight into a user-visible `Details`
string in both callers:

- `lints/rfc/lint_key_usage_and_extended_key_usage_inconsistent.go:116` - `lints/etsi/lint_qc_np_correct_ku_setting.go:86`

Twelve runs of the same binary over the same certificate, three bits set:

```
6 KeyUsage [KeyEncipherment KeyAgreement DigitalSignature]
2 KeyUsage [KeyAgreement DigitalSignature KeyEncipherment]
2 KeyUsage [DigitalSignature KeyEncipherment KeyAgreement]
2 KeyUsage [DigitalSignature KeyAgreement KeyEncipherment]
```

and `"result":"error"` twelve times out of twelve.

**Fix**: `sort.Strings(keyUsageStrings)` before the `return` in `util/ku.go`.
That the intent is sorting is not a guess — two places in this same code
already do it, and the one that matters was missed:

- `util.GetEKUStrings` (`util/eku.go:54`), the sibling helper that renders the *other* half of the very same message, calls `sort.Strings` before returning. - `lint_key_usage_and_extended_key_usage_inconsistent.go:96`, the multiple-purpose branch, calls `sort.Strings(keyUsage)` on the result. The single-purpose branch forty lines later, at :116, does not — the same function sorts one path and not the other.

So this is a slip rather than a design, and fixing the helper fixes both
callers plus the ETSI one at once.

**Low.** No verdict moves and no certificate is judged differently; only the
wording changes.

Found that way, in fact. the reproduction beside this file --check` compares
the reproduction suite against a recorded baseline, and this was the first
thing it reported on the first run after being written.

Fix: `sort.Strings(keyUsageStrings)` before returning, or range over an
ordered slice of (bit, name) pairs instead of the map.
