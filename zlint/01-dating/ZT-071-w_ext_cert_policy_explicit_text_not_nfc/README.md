# ZT-071 — `w_ext_cert_policy_explicit_text_not_nfc` mis-cites its document, mis-dates the `UTF8String` half of its own requirement, and misspells the citation it does carry

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```go
Citation: "RFC6181 3",
```

Two digits transposed: RFC 6181 is *Threat Analysis of the Domain Name System
(DNS)*, unrelated to certificate policies; the intended citation is RFC 6818.

Separately, and more substantively: RFC 5280 (2008) states "When the
UTF8String encoding is used, all character sequences SHOULD be normalized
according to Unicode normalization form C (NFC)" (`Specs/rfc/rfc5280.txt` line
1823); RFC 6818 §3 (2013) widens the same sentence to "the UTF8String **or
BMPString** encoding" (`Specs/rfc/rfc6818.txt` line 189) — a genuine addition,
unlike the two sentences in ZT-087 that RFC 6818 merely repeats. The check
answers both arms under one identifier gated uniformly at `util.RFC6818Date`
(2013-01-01), which is right for `BMPString` and five years late for
`UTF8String`.

**observed**: `Citation: "RFC6181 3"`; `EffectiveDate: util.RFC6818Date`
applied to the `UTF8String` arm.

**correct**: `Citation: "RFC 6818: 3"` (or, better, split by arm: RFC 5280
§4.2.1.4 dated 2008-05-01 for `UTF8String`, RFC 6818 §3 dated 2013-01-01 for
`BMPString`, matching how `e_ext_cert_policy_explicit_text_ia5_string` and
`e_ext_cert_policy_explicit_text_visible_or_bmp_string` are already split in
this same file family for the identical reason).

**fix**: correct the citation spelling; split the check by arm (see above) or,
at minimum, date the `UTF8String` branch `util.RFC5280Date`.

## What was not verified
