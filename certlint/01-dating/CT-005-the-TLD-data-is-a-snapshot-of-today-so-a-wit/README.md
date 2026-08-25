# CT-005 — the TLD data is a snapshot of today, so a withdrawn gTLD reads as never delegated

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ |
| **Verified against** | a corpus certificate and zlint's own fixture |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```
$ cablint positive/CT-005-withdrawn-tld-cancerresearch.pem   # issued 2022-07-22
E: Unknown TLD in SAN
$ cablint positive/CT-005-withdrawn-tld-mcdonalds.pem        # issued 2016-08-08
E: Unknown TLD in SAN
```

`.cancerresearch` was delegated 2014-07-03 and withdrawn 2022-10-05 — eleven
weeks **after** the first certificate was issued. `.mcdonalds` was delegated
2016-08-08 and withdrawn 2017-08-31, and the second certificate is dated
2016-08-08, the day of delegation. Both named a real top-level domain on the
day they were signed.

```
iananames.rb:93   # from https://newgtlds.icann.org/newgtlds.csv
iananames.rb:96   @iana_tlds[l.split(',').first.downcase] = :public
iananames.rb:105  # from http://www.internic.net/domain/root.zone
iananames.rb:109  @iana_tlds[tld] = :public
```

Two files, both snapshots of what is delegated now, into a flat `label →
:public` map with no room for a date. `newgtlds.csv`'s header is
`"tld","u-label","registry-operator","date-of-contract-signature","application-id","delegation-date"`
and `l.split(',').first` keeps the label and drops the rest. Neither label
appears in either file today, so the discarded delegation date would not have
saved these two: what is missing is a **removal** date, which a list of
current delegations cannot carry at all.

Fix: a dated source. ICANN's gTLD v2 JSON registry carries a delegation and a
removal date per label, and zlint derives `util/gtld_map.go` from it with its
own `zlint-gtld-update`. The lookup becomes "was this label delegated on the
certificate's `notBefore`" instead of "is it delegated now".
