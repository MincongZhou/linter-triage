# ZT-002 — `e_ext_cert_policy_explicit_text_too_long` measures bytes where RFC 6818 says characters

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `00-already-filed` — Already on your issue tracker |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, python3 |
| **Cases** | positive/ and negative/ |
| **Verified against** | two real certificates |
| **Would otherwise sit in** | see the adjudication below |

## Upstream issues, adjudicated

- **#242** — Incorrect maximum length constraint checking for explicitText (bytes vs. characters) *(closed)*
  **duplicate.** Reported 2018-11, CLOSED 2019-01 with no fix -- the thread ends with the maintainer noting Go has no BMPString API. Still reproduces on the pinned build.

## Analysis

Observed `error` on an `explicitText` of 200 characters; correct `pass`.

```go
// lint_ext_cert_policy_explicit_text_too_long.go
Description:   "Explicit text has a maximum size of 200 characters",
Citation:      "RFC 6818: 3",
...
if text.Tag == tagBMPString {
    runes, _ = util.ParseBMPString(text.Bytes)
} else {
    runes = string(text.Bytes)
}
if len(runes) > 200 {
```

`runes` is a Go string and `len` on a Go string counts bytes. The BMPString
branch does not escape it: `util.ParseBMPString` returns
`string(utf16.Decode(s))`, which is UTF-8, so `len` counts bytes there too —
its comment, "parse the bytes out into UTF-16-BE runes in order to check their
length accurately", states an intent the code does not carry out. Executed
rather than read:

```
"Certificado cualificado para sede electrónica"  len=46  RuneCount=45
BMPString of 3 code points                       len=6   RuneCount=3
```

RFC 6818 §3 gives the bound in characters: "The explicitText field is a string
with a maximum size of 200 characters."

Fix: `utf8.RuneCountInString(runes) > 200`, in both branches.
