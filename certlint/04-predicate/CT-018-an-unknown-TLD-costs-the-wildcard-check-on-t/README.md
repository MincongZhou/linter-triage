# CT-018 — an unknown TLD costs the wildcard check on that name

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl, a checkout of the tool (the script reads its source) |
| **Cases** | positive/ and negative/ |
| **Verified against** | fabricated pair (recipe in the script) |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```
control  SAN dNSName = *.com      I: Wildcard to immediate left of public suffix in SAN
unknown  SAN dNSName = *.newtld   E: Unknown TLD in SAN
```

Byte-identical certificates one label apart. Changing the TLD *replaces* the
wildcard finding rather than adding to it.

`IANANames.lint` (`lib/certlint/iananames.rb:100-102`) appends `E: Unknown
TLD` and returns, so a `dNSName` whose TLD is in neither `data/root.zone` nor
`data/newgtlds.csv` is never seen by the checks below. One call site,
`cablint.rb:673`, on SAN `dNSName` — `certlint` (DER) never reaches it and is
silent on both fixtures.

**Only one finding is actually lost**, and establishing that took more work
than the defect did. Of the five findings below the return:

| finding | fate |
|---|---|
| `I: Wildcard to immediate left of public suffix` | **lost** — emitted nowhere else |
| `W: Underscore in base domain` | recovered by `GeneralNames.dnsname` |
| `W: Bad IDN A-label in DNS Name` | recovered, identical string |
| `E: FQDN under reserved or special domain` | unreachable by this path anyway |
| `I: Domain is bare public suffix` | unreachable by this path anyway |

The recoveries happen because `CABLint.lint` calls `CertLint.lint` first
(`cablint.rb:79`), which runs the RFC layer. The two unreachable ones are
proven by enumeration rather than argument: every special-domain suffix ends
in a label that is itself in the TLD table, so a name matching one cannot have
an unknown TLD.

So the issuer's choice of TLD decides whether cablint applies its only check
for the shape BR §3.2.2.6 governs.

**Medium rather than High**, deliberately. Both of High's structural triggers
are satisfied — the subject controls whether the check runs, which is the
`another entry here` shape, and one return takes other checks down with it.
But High leads with *reports conformance it did not verify*, and cablint does
not: it emits `E: Unknown TLD in SAN` on the same name it stopped checking.
One finding is substituted for another, not suppressed into silence. The
residual hazard is operational — an operator who allowlists `E: Unknown TLD`
for a newly delegated gTLD silently loses the wildcard check with it.

none also carries a wildcard, underscore or malformed A-label, so none loses a
finding today.

The same return makes the `rescue PublicSuffix::DomainInvalid` branch at line
136 unreachable for the case its own comment describes — "We got this far, so
assume this is a new tld". The handler was written for exactly what the early
return prevents, which makes the fix self-evident.

Fix: `messages << 'E: Unknown TLD' if tld_type.nil?` and let the method
continue. That restores the wildcard check and makes the rescue reachable,
with no other change.

Claims investigated and refuted are in [REFUTED.md](REFUTED.md), with the
evidence. They carry no number.
