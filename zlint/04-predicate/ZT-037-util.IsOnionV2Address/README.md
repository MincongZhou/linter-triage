# ZT-037 — `util.IsOnionV2Address` reads the wrong label

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool |
| **Cases** | positive/ and negative/ |
| **Verified against** | fabricated pair |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

Observed `NA` for `www.<v2addr>.onion`, `error` for `<v2addr>.onion`; correct
`error` for both.

`util/onion.go:47` checks `labels[0]`. Its own doc comment says "the
second-to-the-right most label", and both `IsOnionV3Address` and
`lint_san_dns_name_onion_invalid.go:125` use `labels[len(labels)-2]`. The
consequence: an EV certificate for a v2 onion service behind any subdomain
gets `NA` from the only lint checking for a TorServiceDescriptor extension.
Conversely `<v2addr>.www.onion` is reported as a v2 onion certificate.

zlint disagrees with itself: `e_san_dns_name_onion_invalid` returns `pass` on
the subdomain form, accepting as a v2 address what this helper denies.

Fix: `labels[len(labels)-2]`, after the existing `len(labels) < 2` check.
