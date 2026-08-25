# CT-029 — `Duplicate SAN entry` compares across `GeneralName` types

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | two real incident certificates plus a five-line Ruby reproduction of the mechanism |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

### The code

`lib/certlint/cablint.rb`, inside the `SubjectAltName` walk:

```ruby
when 2                                    # dNSName, line 654
  val = genname.value
  ...
  nameval = val.downcase.force_encoding('US-ASCII') # A-label   -- line 674
when 7                                    # iPAddress, line 687
  ...
  n = IPAddr.new_ntoh(genname.value)
  nameval = n.to_s.downcase                                    # line 694
...
if names.include? nameval                                      # line 704
  messages << 'W: Duplicate SAN entry'
else
  names << nameval
end
```

`names` is one flat array. A `dNSName` and an `iPAddress` are pushed into it
as bare strings with no tag carried alongside, so the membership test at line
704 cannot tell a coincidence of *rendering* from a coincidence of *identity*.

### Reproduction

```
$ cablint 
```

```
I: TLS Server certificate identified
E: Unknown TLD in SAN
W: Duplicate SAN entry
```

The certificate's `subjectAltName` holds exactly two entries:

```
DNSName    217.109.29.227
IPAddress  217.109.29.227
```

Two different `GeneralName` alternatives, chosen by two different context tags
(`[2]` and `[7]`), naming two different things under RFC 5280 §4.2.1.6 — a
`dNSName` is matched against a hostname, an `iPAddress` against a 4- or
16-octet address, and a client never compares one to the other. certlint's own
sibling message, `E: Unknown TLD in SAN`, is on the same finding list and
correctly treats the `217.109.29.227` `dNSName` as *not a valid domain name at
all* — which is the right read of that entry and is inconsistent with also
calling it a duplicate of a real `iPAddress` entry one line later.

The five-line reproduction of the mechanism, isolated from certificate parsing
entirely:

```
$ ruby -e '
names = []
["DNSName:217.109.29.227", "IPAddress:217.109.29.227"].each do |tagged|
  nameval = tagged.split(":", 2).last.downcase   # both branches strip the tag before comparing
  puts(names.include?(nameval) ? "DUPLICATE: #{nameval}" : "new: #{nameval}")
  names << nameval
end'
new: 217.109.29.227
DUPLICATE: 217.109.29.227
```

**Control**, same shape, confirming the check works correctly when the
`GeneralName` types genuinely match: a certificate from Mozilla CA incident
[bug 1611458](https://bugzilla.mozilla.org/show_bug.cgi?id=1611458) carries
seven `iPAddress` entries, each listed twice, and certlint reports `W:
Duplicate SAN entry` seven times — the correct outcome for a real same-type
repeat, and the case this rule exists for.

### What would fix it

Carry the `GeneralName` tag alongside each `nameval` pushed into `names` — a
`(tag, value)` pair or two separate arrays — and compare only within a tag.

### What was not verified
