# ZT-059 — `e_ext_cannot_be_empty_sequence` returns inside a map range, so which of several defective extensions it reports is a coin toss

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `07-robustness` — Panics, run-ending failures, and non-determinism |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, python3 |
| **Cases** | positive/ |
| **Verified against** | zlint's `frshCRLNotCritical.pem` unmodified, plus one constructed certificate for the status case (recipe in the script) |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

`lints/rfc/lint_ext_cannot_be_empty_seq.go`:

```go
for extOid := range targetExtensionsMap {                // ten extensions, a map
	if ext, found := c.ExtensionsMap[extOid]; found {
		_, err := asn1.Unmarshal(ext.Value, &SequenceOfSomething)
		if err != nil {
			return &lint.LintResult{Status: lint.Fatal, ...}   // returns
		}
		if len(SequenceOfSomething) == 0 {
			return &lint.LintResult{Status: lint.Error, ...}   // returns
		}
```

Go randomises map iteration order on every call and both branches `return` on
the first hit. A certificate with two defective target extensions therefore
gets one of them reported, chosen at random, and **the other is never reported
at all**.

This is not ZT-057 restated. There, map order changed how a finding was
*worded*; here it changes *which finding you get*, and it can change the
status.

### On zlint's own fixture, unmodified

`frshCRLNotCritical.pem` carries `SubjectInformationAccess` and `FreshestCRL`
with byte-identical malformed contents — `extnValue` is `0201` in both, a
truncated INTEGER where a SEQUENCE belongs. Forty runs of one binary over that
one file:

```
31  fatal  Cannot parse the SubjectInformationAccess extension: …
 9  fatal  Cannot parse the FreshestCRL extension: …
```

### And the status moves, not only the name

```
29  error  The SubjectInformationAccess extension, if present, MUST contain at least 1 element
11  fatal  Cannot parse the FreshestCRL extension: …
```

One binary, one certificate, two statuses. Two consumers disagree, and a
re-run disagrees with itself.

**Fix**: build a sorted key slice and iterate that, and accumulate rather than
returning on the first hit:

```go
oids := make([]string, 0, len(targetExtensionsMap))
for oid := range targetExtensionsMap { oids = append(oids, oid) }
sort.Strings(oids)
```

Sorting makes the report deterministic; accumulating makes it complete.
