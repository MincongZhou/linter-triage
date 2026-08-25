# ZT-089 — `w_subject_contains_malformed_arpa_ip`'s `CheckApplies` reads the commonName; `Execute` does not

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | reproduced on a real CA-incident certificate |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```go
func (l *arpaMalformedIP) CheckApplies(c *x509.Certificate) bool {
	names := append([]string{c.Subject.CommonName}, c.DNSNames...)
	...
}

func (l *arpaMalformedIP) Execute(c *x509.Certificate) *lint.LintResult {
	for _, name := range c.DNSNames {
		...
```

**observed**: `CheckApplies` decides whether to run this lint by reading the
commonName *and* the SAN dNSNames; `Execute` then iterates `c.DNSNames` alone.
A certificate whose only malformed reverse-mapping name is in the commonName
field satisfies `CheckApplies` (so the lint runs) but is never examined by
`Execute` (so it reports `Pass` rather than `Warn`). **correct**: a malformed
reverse-mapping name in the commonName should draw the same warning a SAN
dNSName instance would.

**mechanism**: a Go slice built in one method (`append([]string{...},
c.DNSNames...)`) and a different slice (`c.DNSNames`) read in another. Plain
control flow, executed to confirm — see reproduction below — rather than
merely read, per this skill's standard.

```
$ zlint -includeNames w_subject_contains_malformed_arpa_ip \
    
{"w_subject_contains_malformed_arpa_ip":{"result":"warn"}}
```

**Not ported as zlint states it.** This lane's
`w_subject_contains_malformed_arpa_ip` reads both fields through
`decode::host_names::claimed`, the same shared reader
`e_subject_contains_reserved_arpa_ip` already uses for the same reason.

## What was not verified
