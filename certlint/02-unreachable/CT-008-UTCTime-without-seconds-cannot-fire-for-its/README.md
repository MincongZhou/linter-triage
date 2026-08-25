# CT-008 — `UTCTime without seconds` cannot fire for its own defect, and every firing is false

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `02-unreachable` — Checks that cannot fire |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl, a checkout of the tool (the script reads its source) |
| **Cases** | positive/ and negative/ |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

Two facts that only meet at run time.

**One: the regex conflates the zone with the seconds.**
`lib/certlint/certlint.rb:283-285`:

```ruby
if value !~ /\A([0-9]{2})([01][0-9])([0-3][0-9])([012][0-9])([0-5][0-9]){2}Z\z/
  messages << 'E: UTCTime without seconds'
end
```

The trailing `Z\z` means a UTCTime that *has* seconds but carries an offset
zone fails this regex. Five lines above, `unless value =~ /Z\z/` already
reports that as `E: Time not in Zulu/GMT` — correctly. So such a certificate
draws both, one true and one false.

**Two: a UTCTime without seconds never reaches line 284.** Ruby's
`OpenSSL::ASN1` refuses it outright — `utctime is too short` — which
`check_pdu` records as `F: Decode error in Certificate` at `certlint.rb:114`.
`lint` then bails at `certlint.rb:263`:

```ruby
# Ensure that we bail on fatal errors
if messages.any? { |m| m.start_with? 'F:' }
  return messages
end
```

and returns before the time traverse at line 268 begins.

**So the check's true population is unreachable and its actual population
belongs to the other message.** Measured 2026-08-22: 3 certificates fire it
and all 3 have seconds; 3 others genuinely lack seconds and draw the `F:`
instead. The check has never once reported its own requirement.

The reproduction uses a real certificate for the false-positive half:
SecureNet CA Class B, a 1999 root whose two UTCTimes are `990630000000+1000`
and `091015235900+1000` — twelve digits each, seconds present, drawing the
message twice.

**A note on how the mechanism was established, because the first reading was
wrong.** `OpenSSL::ASN1.traverse` yields the block *before* raising on a value
it cannot decode, so reading the traverse suggests the check runs and its
finding is then discarded. Executed on a bare seconds-less UTCTime, the block
does run and the raise follows. That is not what happens in a certificate: the
bail at line 263 means the traverse is never entered. Right verdict, wrong
mechanism, and the mechanism is what a maintainer acts on.

**Fix**, for the half that is fixable here — drop the zone from this regex,
since the line above owns that requirement:

```ruby
if value !~ /\A[0-9]{12}(Z|[+-][0-9]{4})\z/
```

The unreachable half is not fixable in this file. While the decoder refuses a
seconds-less UTCTime, no check downstream of `check_pdu` can see one;
reporting it means recognising the shape inside `check_pdu`'s rescue, raising
the message from the decode error rather than from a value test.
