# ZT-062 — two lints anchor `+` against a value that may be empty

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `08-hygiene` — Descriptions, citations, severities and tests |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | zlint's own fixture |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

Observed `error` with a message naming a character; correct `pass`, the value
having no characters.

```go
// lint_subject_printable_string_badalpha.go
printableStringRegex = regexp.MustCompile(`^[a-zA-Z0-9\=\(\)\+,\-.\/:\? ']+$`)
    ... errors.New("encoded PrintableString contained illegal characters")

// lint_subj_country_not_uppercase.go
var re = regexp.MustCompile("^[A-Z]+$")
    ... Details: "Country codes must be comprised of uppercase A-Z letters",
```

Both quantifiers are `+`, so neither pattern matches an empty string, and both
lints read "did not match" as "holds a prohibited character". Executed:

```
""     match=false
"US"   match=true
"a_b"  match=false
" "    match=true
```

On `caBlankCountry.pem` — zlint's own fixture, `countryName` present and empty
— five lints fire. Three of them say what is wrong:
`e_ca_country_name_missing`, `e_ca_country_name_invalid` and
`e_subject_country_not_iso`. The other two report a character set violation of
a value with no characters.

No conformance verdict changes; every affected certificate is non-conformant
for the reason the other three lints give. What changes is the reason and the
count, which is [ZT-013](#zl-022)'s argument again.

Fix: `*` in place of `+` in both patterns with an explicit emptiness test, or
a `len > 0` guard leaving the empty case to the lints that own it.
