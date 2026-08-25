# ZT-038 — `e_generalized_time_includes_fraction_seconds` fires where no fraction exists

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | zlint's own fixture, `notAfter` rewritten |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

Observed `error` on `20571201060708+0500`; correct `pass`.

`checkFraction` picks its length limit by reading the last octets of the raw
time:

```go
if t.Bytes[len(t.Bytes)-1] == 'Z' {
    if len(t.Bytes) > 15 { *r = lint.Error }
} else if t.Bytes[len(t.Bytes)-5] == '-' || t.Bytes[len(t.Bytes)-1] == '+' {
    if len(t.Bytes) > 19 { *r = lint.Error }
} else {
    if len(t.Bytes) > 14 { *r = lint.Error }
}
```

The offset branch looks for `-` five octets from the end and for `+` at the
last octet. In `YYYYMMDDHHMMSS+hhmm` the `+` is five octets from the end, so a
positive offset misses that branch and falls through to `len > 14`, which
every 19-octet offset form satisfies. The verdict turns on the sign of the
offset:

```
notAfter 20571201060708+0500   fraction_seconds error   not_in_zulu error
notAfter 20571201060708-0500   fraction_seconds pass    not_in_zulu error
notAfter 20571201060708Z       fraction_seconds pass    not_in_zulu pass
```

The two case certificates are zlint's own well-formed GeneralizedTime fixture
— the control [ZT-023](#zl-009) uses — with the `notAfter` value rewritten and
the enclosing lengths re-encoded. They differ from each other in one octet.

Neither value holds a fractional second: the seconds field is `08` in both,
and what follows is a time differential. The nonconformity that is present is
the departure from Zulu, which `e_generalized_time_not_in_zulu` already
reports on both — so this finding puts a wrong reason beside a correct one.

It is also the only reachable path into the lint. [ZT-023](#zl-009) records
that the parser refuses every certificate carrying a real fractional second,
so the one input that makes this lint fire is the one input it is not about.

`checkSeconds` in the sibling file misreads the same index and is harmless
there: its fall-through tests `len < 14`, which no 19-octet offset form
satisfies. One typo, one lint affected.

Fix: test for `+` five octets from the end, alongside `-`, rather than at the
last octet.
