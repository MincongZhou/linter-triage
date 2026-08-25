# CT-023 — `Generalized Time before 2050` has no lower bound, so it demands an impossible encoding

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl, a checkout of the tool (the script reads its source) |
| **Cases** | positive/ |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

`lib/certlint/certlint.rb:291-293`, inside the time-field traverse:

```ruby
if value[0..3] < '2050'
  messages << 'E: Generalized Time before 2050'
end
```

A string comparison with an upper bound and no lower one. The message means
*this should have been a UTCTime*, and RFC 5280 §4.1.2.5.1 gives UTCTime a
two-digit year interpreted as 1950–2049 and nothing else. `'0001'` sorts below
`'2050'` exactly as `'2049'` does, so a GeneralizedTime of year 1 is reported
as needing an encoding that cannot represent it.

RFC 5280 §4.1.2.5 requires GeneralizedTime for dates "in 2050 or later" and
UTCTime for dates "through the year 2049". A date before 1950 falls outside
both halves; the clause says nothing about it, and neither should a message
whose named correction is impossible.

**Fix**: bound it below, `value[0..3] < '2050' && value[0..3] >= '1950'`. A
date outside 1950–2049 in either direction is a validity-range question and
wants a different message.

Third implementation, second to get it wrong — which is the reason it is
written down rather than quietly patched.
