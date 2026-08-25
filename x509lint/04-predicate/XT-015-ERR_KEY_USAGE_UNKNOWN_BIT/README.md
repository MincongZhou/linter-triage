# XT-015 — `ERR_KEY_USAGE_UNKNOWN_BIT` reads only the first two content octets, so a `keyUsage` longer than that never draws it

| | |
|---|---|
| **Tool** | `kroeckx/x509lint` at `103c92f` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

### The code

```c
int bits = 0;
if (usage->length > 0)
{
    bits = usage->data[0];
}
if (usage->length > 1)
{
    bits |= (usage->data[1] << 8);
}
if ((bits & 0x80FF) != bits)
{
    SetError(ERR_KEY_USAGE_UNKNOWN_BIT);
}
if (usage->length > 2)
{
    SetError(ERR_KEY_USAGE_TOO_LONG);
}
```

`bits` is built from `usage->data[0]` and `usage->data[1]` only — the first
two content octets. A third or later octet is never read into `bits`, so a set
bit anywhere past the sixteenth position can never trip the `0x80FF` mask
test, however far it is from the nine bits RFC 5280 § 4.2.1.3 actually
defines.

### What the citation actually states

No citation in the source at either site, but the requirement both sites
gesture at is the same one: RFC 5280 § 4.2.1.3 defines exactly nine `keyUsage`
bits. `ERR_KEY_USAGE_UNKNOWN_BIT` is x509lint's attempt at "a bit past
`decipherOnly` is asserted"; `ERR_KEY_USAGE_TOO_LONG` is a blunter proxy for
the same population — "the encoding is longer than two content octets can
need." They are not the same check, and the second one is reached first by
`usage->length > 2` regardless of what the extra octets contain, so a
non-minimal-but-otherwise-empty third octet (padding) and a third octet
carrying a genuine out-of-range bit both report only `TOO_LONG`, never
`UNKNOWN_BIT`.

### What would fix it

Read the whole content region against the declared `unused` bit count — the
same computation `e_key_usage_incorrect_length` performs — rather than
hard-coding two octets.

### How this lane handled it

Not ported as a fix to x509lint's shape.
`checks.c::ERR_KEY_USAGE_UNKNOWN_BIT::1` is recorded `answered` by
`e_key_usage_incorrect_length`, which implements the clause (any bit past the
ninth, wherever it falls) rather than x509lint's 2-octet-limited code.
`checks.c::ERR_KEY_USAGE_TOO_LONG::1` is recorded `answered` by the same
identifier together with `e_incorrect_ku_encoding` (X.690 § 11.2.2
minimality), which jointly cover every `length > 2` case: an out-of-range set
bit, or an all-zero trailing octet.
