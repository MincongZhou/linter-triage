# CT-026 — serial-number entropy is split by signature hash strength, a distinction the Baseline Requirements never made

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | , a vendored zlint fixture |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

### The code

```ruby
if sa == :weak && c.serial.num_bytes < 8
  messages << 'W: Serial numbers for certificates using weaker hashes should have at least 64 bits of entropy'
elsif sa == :pss
  messages << 'W: PSS is not supported by most browsers'
end
end

if sa != :weak && c.serial.num_bits < 20
  messages << 'W: Serial numbers should have at least 20 bits of entropy'
end
```

`lib/certlint/cablint.rb:102-111`. `sa` is the certificate's signature
algorithm classified `:weak` (SHA-1), `:good` (SHA-256/384/512, ECDSA
variants) or `:pss`. A weak-hash certificate is held to a 64-bit floor; every
other certificate is held to a 20-bit floor. Neither message cites a section.

### What the Baseline Requirements actually said, by date

- BR v1.0.0 (2012-07-01) § 9.6 through v1.3.6 (2016-07-01) § 7.1: "CAs SHOULD generate non-sequential Certificate serial numbers that exhibit at least 20 bits of entropy." No mention of the signature algorithm anywhere in this sentence or its section, in any version searched. - BR v1.3.7 (2016-09-30, Ballot 164) § 7.1 onward: "CAs SHALL generate Certificate serial numbers greater than zero (0) containing at least 64 bits of output from a CSPRNG." Also unconditional on hash strength.

The document changed **the threshold over time**, uniformly. It never changed
**the threshold by algorithm**. cablint's split has no clause behind it in
either wording, in any version examined.

### The direction that matters: a weak-hash certificate compliant in its own era is reported

Because CABF's SHA-1 sunset (`NO_SHA1`, this file's own `Time.utc(2016, 1,
1)`) predates the 64-bit SHALL by nine months, almost every `:weak`
certificate in circulation was issued while the document asked for 20 bits,
not 64. cablint checks it against 64 anyway.

```
$ ruby -I lib -I ext bin/cablint 
W: Serial numbers for certificates using weaker hashes should have at least 64 bits of entropy
```

`sha1WithRSASignatureAlgorithm.pem`: notBefore 2014-06-30 (inside the 20-bit
era, nowhere near the 64-bit one), serial 21 significant bits. **observed**:
an entropy warning against a 64-bit floor. **correct**: no warning — 21 bits
clears the 20-bit floor the document actually stated on 2014-06-30, and
cablint's own predicate for the *unconditional* 20-bit message (`sa != :weak`)
would have said so if the certificate's hash were not the thing gating which
message runs.

### Reach

```
weak-hash (sha1) certificates: 51
  of those, 20 <= significant bits < 64: 14   <- cablint's false positives
BR-window (2012-07-01 .. 2016-09-30) certificates: 377
  of those, significant bits < 20: 24          <- real § 7.1/§9.6 SHOULD violations,
                                                    correctly caught regardless of hash
```

The 14 false positives are certificates that satisfied the entropy floor in
force when they were issued and are reported anyway, solely because their
signature used SHA-1. The 24 real violations are caught correctly by both
messages' union — the split does not cost cablint any true positives here,
only the 14 false ones.

### What a faithful implementation looks like

Neither reads the signature algorithm at all.

### Fix

Drop the `sa == :weak` / `sa != :weak` branch and gate the threshold on
`c.not_before` against Ballot 164's effective date instead — the same fix the
reproduction beside this file CT-003 and CT-004 propose for this file's other
undated and mis-dated checks.

## Corpus confirmation, added by the integrator

```
intermediate-2e7e65bb1a013daf.der   notBefore 2013-08-06, serial 18 bits
intermediate-5d74ed61d0b311e9.der   notBefore 2012-08-22, serial 18 bits
```

Both are inside the 20-bit era, both are eighteen bits, and both draw

```
W: Serial numbers for certificates using weaker hashes should have at least
   64 bits of entropy
```

— not the 20-bit message. cablint reports them, so nothing is missed; it
reports them **against a floor that was four years away**, and tells the
reader the requirement is about their hash when it is about their date. A CA
acting on that message would conclude it needed 64 bits in 2012, which the
Baseline Requirements did not ask for until Ballot 164 took effect on
2016-09-30.

This is the same single `sa == :weak` test the entry above describes, seen
from the reporting side rather than the missing side. It does not change the
verdict or the severity; it means the over-report half is not confined to a
fixture.
