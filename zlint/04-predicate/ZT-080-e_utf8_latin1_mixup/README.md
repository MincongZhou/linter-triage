# ZT-080 — `e_utf8_latin1_mixup`'s table omits two manglings whose second character is invisible, and one of them is `à`

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, python3, a checkout of the tool (the script reads its source) |
| **Cases** | positive/ and negative/ |
| **Verified against** | two certificates from one CA incident, one of them the control |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```go
// This table does not cover 100% of all possible miscodings, but it
// avoids false positives.
miscodedDiacritics := []string{
    "Ã€", // À
    "Ã‚", // Â
    …
```

57 entries, every one beginning `U+00C3`. That is the right shape: a Latin-1
letter `U+00E0..U+00FF` encodes in UTF-8 as `C3 xx`, and reading those two
bytes back as Windows-1252 yields `U+00C3` followed by whatever cp1252 maps
`xx` to. There are 64 such letters. Enumerating them against the table shows
**seven absent**, and they are not a random seven:

| absent | the mangling |
|---|---|
| `à` | `U+00C3 U+00A0` — NO-BREAK SPACE |
| `í` | `U+00C3 U+00AD` — SOFT HYPHEN |
| `Á` `Í` `Ï` `Ð` `Ý` | second byte undefined in cp1252 |

**Both of the first two have an invisible second character.** A no-break space
and a soft hyphen render as nothing, or as an ordinary space, in every editor
and every terminal — so a table assembled by pasting samples of real mojibake
loses exactly these two in the paste, and the loss is invisible in review as
well. The remaining five are bytes cp1252 leaves undefined, which a UTF-8
source file cannot carry as a literal at all. So the omissions are systematic
rather than a sampling accident, which is the reason this is filed at all: the
comment concedes the table is incomplete, and a list of what it is incomplete
*about* is the part a maintainer can act on.

`à` is the one that matters. It is an ordinary letter of Italian, French,
Portuguese, Catalan and Occitan, and `Autorità` — Italian for *authority* — is
a word that appears in the legal names of public bodies that hold TLS
certificates.

The reproduction uses two certificates from **Mozilla [bug
1724458](https://bugzilla.mozilla.org/show_bug.cgi?id=1724458)**, Sectigo,
2021-08-06, an incident whose subject is precisely this defect class —
*"certificates containing Mojibake in place of UTF-8 encoded Extended ASCII
characters"*:

| certificate | value | zlint |
|---|---|---|
| `crtsh3732536359` | `O=AutoritÃ␠di Sistema Portuale…` | **pass** |
| `crtsh4420344894` | `L=Cerdanyola del VallÃ¨s` | error |

**Fix**: two entries, written as Go escapes rather than literals so the
invisible characters survive review and the next paste — `"\u00c3\u00a0", //
à` and `"\u00c3\u00ad", // í`. Writing them as literals is how the table came
to be missing them. The five undefined bytes need the table to hold something
a UTF-8 literal cannot, which is a different change and may not be worth
making.
