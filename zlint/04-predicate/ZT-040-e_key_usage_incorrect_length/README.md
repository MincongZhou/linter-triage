# ZT-040 — `e_key_usage_incorrect_length` measures the highest set bit, not the declared length

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl, python3 |
| **Cases** | positive/ and negative/ |
| **Verified against** | fabricated pair (recipe in the script) plus zlint's own fixture |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

Observed `pass` on a `keyUsage` asserting an undefined bit; correct `error`.
And `error` on a `keyUsage` asserting nothing but defined bits; correct
`pass`.

```go
unused := kuBytes[2]
kuBig := big.NewInt(0).SetBytes(keyUsageVal.Bytes)
if !kuBig.IsInt64() || kuBig.Int64()>>unused >= 512 {
```

`kuBig >> unused` right-aligns the value and `>= 512` asks whether writing it
down needs ten bits or more. That is the position of the highest *set* bit,
which is not the number of bits the BIT STRING declares. Both directions
follow. Executed against the function copied verbatim:

```
03 02 07 80     digitalSignature, minimal                 -> pass
03 03 07 08 80  keyAgreement+decipherOnly, minimal        -> pass
03 03 00 08 80  keyAgreement+decipherOnly, unused=0       -> error
03 03 06 00 40  ONLY undefined bit 9 asserted             -> pass
03 03 00 00 01  ONLY undefined bit 15 asserted            -> pass
03 03 06 80 40  digitalSignature + undefined bit 9        -> error
```

The false negative is the serious half, and it is the shape
[README.md](README.md#severity) calls the serious one: a certificate asserting
a `keyUsage` bit RFC 5280 does not define escapes the lint whenever every
defined bit is clear, so the subject of the check decides whether the check
reaches a verdict. The reproduction's two files differ in one bit — both
declare ten bits and both assert undefined bit 9, and it is adding
`digitalSignature` to the control that makes the lint notice the undefined bit
it missed on the case.

The false positive is the third line: a `keyUsage` whose bits are all defined
but whose BIT STRING was not minimally encoded. `e_incorrect_ku_encoding`
already reports it and gets it exactly right — "the number of 'unused bits' is
declared to be 0, but it should be 7" — while this lint says the value
"contains a value that is out of bounds of the range of possible KU values"
about `0x08 0x80`, which is `keyAgreement` and `decipherOnly`.

Fix: test the declared length. The used bit count is `len(keyUsageVal.Bytes)*8
- int(unused)`; error when a bit at position 9 or beyond is set inside it.
That reports the case, keeps the control, and leaves the non-minimal encoding
to `e_incorrect_ku_encoding`.
