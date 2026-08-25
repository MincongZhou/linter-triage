# ZT-043 — `e_utf8_latin1_mixup` reads only the first value of each field

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | Mozilla bug 1431164's `crtsh305441195`, with bug 1715024's `crtsh2126599075` as the control |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

The lint names twelve fields of `x509.Certificate.Subject`, each a `[]string`,
and reads index 0 of each:

```go
strSlice := field.Interface().([]string)
if len(strSlice) > 0 {
    if containsUtf8Latin1Mixup(strSlice[0]) {
```

A distinguished name may carry an attribute more than once, and
`organizationalUnitName` routinely does. Where the damage is in the second
occurrence the certificate passes.

**Two real certificates, differing in which index the damage sits in.** From
bug 1431164, a Spanish municipal CA:

```
OU: sede electrónica                                          <- correct
OU: SEDE ELECTRONICA DEL AYUNTAMIENTO DE LA TORRE DÂEN BESORA  <- damaged
e_utf8_latin1_mixup: pass
```

```
OU: Sistemas de InformaciÃ³n     <- damaged
OU: PremiumSSL Legacy Wildcard
e_utf8_latin1_mixup: error
  Subject.OrganizationalUnit contains wrongly encoded diacritics
```

Both subjects carry two `organizationalUnitName` attributes; only the order of
the damage differs.

**Medium.** It fails to report in a bounded population, and the population —
any subject repeating an attribute — is not small. The check's `Source` is
`Community` rather than a normative document, which is an argument for reading
its output as advice; it is registered as `e_` and returns `lint.Error`, so a
consumer treating zlint errors as blocking gets a pass here that it should
not.

Its `n_utf8_latin1_mixup` reads every attribute and every value, and states
the mis-decoding as a rule — two lead characters followed by one in
U+0080..U+00BF — rather than enumerating pairs. 18 firings against zlint's 16;
the second difference is `Ã` followed by a non-breaking space, a pair absent
from zlint's table, which its own comment says is incomplete. That one is not
a defect.)*

Fix: iterate the slice rather than indexing it, in both lints.
