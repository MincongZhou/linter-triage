# ZT-065 — `e_rsa_public_exponent_too_small` publishes another lint's description

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `08-hygiene` — Descriptions, citations, severities and tests |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool |
| **Cases** | positive/ |
| **Verified against** | Bugzilla 2056489's `crtsh25591434222`, a real certificate with `e = 3` |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

BR 6.1.6 states two requirements in one sentence — a SHALL that the exponent
be odd and at least 3, and a SHOULD that it lie in 2^16+1 … 2^256-1. Three
lints cite the clause, and they divide it correctly between them:

| lint | predicate | status |
|---|---|---|
| `e_rsa_public_exponent_not_odd` | `key.E.Bit(0) != 1` | error |
| `e_rsa_public_exponent_too_small` | `key.E.Cmp(big.NewInt(3)) < 0` | error |
| `w_rsa_public_exponent_not_in_range` | outside 2^16+1 … 2^256-1 | warn |

**The first two publish the identical `Description`**, and it describes the
whole SHALL:

```
2 RSA: Value of public exponent is an odd number equal to 3 or more.
1 RSA: Public exponent SHOULD be in the range between 2^16 + 1 and 2^256 - 1
```

`e_rsa_public_exponent_too_small` does not test oddness. A reader given only
its name and description would conclude that a `pass` from it means the
exponent was confirmed odd and at least 3; it means only the latter.

**Not a coverage gap, and not a defect in any predicate.** Each of the three
lints does what its own code says, and between them the clause is fully
covered — `w_rsa_public_exponent_not_in_range` implements the SHOULD exactly,
including both bounds. The artefact is confined to metadata.

The name compounds it. "too small" names the SHOULD's lower bound, and the
lint implements the SHALL's; the lint that does implement the SHOULD is named
"not in range". Renaming a shipped identifier is an interface change and not
worth it for this, but it is why the description matters more here than it
would elsewhere: the name gives a reader no way to catch the description being
wrong.

Fix: a description naming its own predicate — `RSA: Value of public exponent
is 3 or more.`
