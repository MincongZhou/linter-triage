# CT-039 — BR § 7.1.4.3's character-for-character clause has no message

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `09-absent` — A requirement no check covers |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | two real incident certificates |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```
$ cablint positive/CT-039-cn-case-differs-from-san.pem
   (nothing about the commonName)

   subject=C=CH, ST=ZG, L=Zug, O=Kanton Zug, CN=ZG-VSW-GERESP02.zg.ch
   DNS:zg-vsw-geresp02.zg.ch, DNS:zg-vsw-geresp02.msworld.zg.ch, DNS:geres.zg.ch
```

> If the value is a Fully-Qualified Domain Name or Wildcard Domain Name, then
> the value MUST be encoded as a **character-for-character copy** of the
> `dNSName` entry value from the `subjectAltName` extension.

`ZG-VSW-GERESP02.zg.ch` is not a character-for-character copy of
`zg-vsw-geresp02.zg.ch`. The control — a `commonName` of `ov` against a
`dNSName` of `www.test.cn` — is reported, so the membership check works and
this is the clause rather than the code path.

**This is not a bug in the check, and that distinction is the point.**

```
cablint.rb:723  # To check that the CN matches a SAN entry, first check for
                # case insensitive direct match
cablint.rb:725  # RFC 5891 section 3.1.2 makes this clear:
                #  A pair of A-labels MUST be compared as case-insensitive ASCII
cablint.rb:731  unless names.include? val.downcase
```

The comparison is deliberate, reasoned and correct about DNS. Its message says
"must be from SAN entries", which is a claim about **membership**, and it
answers that claim exactly. What no cablint message covers is the **encoding**
clause the Baseline Requirements added separately — which is not a DNS
comparison question at all, since two spellings of the same host can differ
under it.

On the subject certificate zlint reports the encoding lint as `error` and the
membership lint as `NE`, its era having passed.

Fix: a second comparison after the case-insensitive one, for certificates
issued on or after BR 1.8.0 (2021-08-25). The values are already in hand at
line 731 — `names` holds the downcased entries and `val` the original, so the
exact forms have to be carried alongside.
