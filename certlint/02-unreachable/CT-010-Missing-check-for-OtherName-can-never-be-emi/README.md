# CT-010 — `Missing check for OtherName …` can never be emitted

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `02-unreachable` — Checks that cannot fire |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

### The code

`lib/certlint/generalnames.rb:54-71`:

```ruby
OTHERNAMES = {
  '1.2.410.200004.10.1.1' => nil,
  '1.3.6.1.2.1.32' => nil,
  # ... 20 more entries, every one => nil
}

def self.othername(value, is_constraint = false)
  messages = []
  oid = value.first.oid
  if OTHERNAMES.key?(oid)
    checker = OTHERNAMES[oid]
    case checker
    when nil
      messages << "I: No checks for OtherName type #{oid}"
    else
      messages << "I: Missing check for OtherName #{checker}"
    end
  else
    messages << "I: No checks for unknown OtherName type #{oid}"
  end
  messages
end
```

### Why the `else` arm is unreachable

Every value in the `OTHERNAMES` hash literal is the literal `nil` — 22
entries, `'<oid>' => nil` each time, no exceptions. `checker` is therefore
always `nil` whenever `OTHERNAMES.key?(oid)` is true, and Ruby's `case... when
nil` matches `nil` on the `when nil` arm, not the `else`. Confirmed by
executing the identical shape:

```ruby
$ ruby -e '
OTHERNAMES = { "a" => nil, "b" => nil }
oid = "a"
checker = OTHERNAMES[oid]
case checker
when nil
  puts "branch: nil (No checks)"
else
  puts "branch: else (Missing check for #{checker})"
end'
branch: nil (No checks)
```

No input reaches the `else` arm as the table stands: doing so would require an
entry in `OTHERNAMES` whose value is not `nil`, and there is none. The message
`"I: Missing check for OtherName #{checker}"` is therefore printed by no
certificate, however constructed.

### What would fix it

Either delete the dead `else` arm (and the `case` becomes a plain check for
key presence), or give the table a real second state — e.g. a symbol or a
method reference — for an `OtherName` type whose value the table's own author
intended to flag as "known but requires a check nobody wrote yet", distinct
from "known and needs none". As it stands, the two states the code appears to
distinguish collapse to one.

### What was not verified

Whether the maintainers intended the `else` arm to be live once and some past
edit set every value to `nil`, or whether it was always dead code, was not
investigated — this is a report about the current source's behaviour, not
about its history.
