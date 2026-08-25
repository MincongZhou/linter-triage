# CT-011 — `dnsname`'s own `is_a? String` guard can never be reached

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

`lib/certlint/generalnames.rb:153-162`:

```ruby
def self.dnsname(orig_fqdn, is_constraint = false)
  messages = []
  if orig_fqdn.nil? || orig_fqdn.empty?
    messages << 'E: DNSName is empty'
    return messages
  end
  if !orig_fqdn.is_a? String
    messages << 'F: DNSName is not a string'
    return messages
  end
  ...
```

and its sole caller, `lib/certlint/generalnames.rb:222-227`:

```ruby
when 2 # DNSName
  if !genname.value.is_a? String
    messages << 'F: DNS Name is not a String'
    return messages # Fatal
  end
  messages += dnsname(genname.value, !is_san)
```

### Why the guard is unreachable

`dnsname` is a `def self.` method, and the only call to it anywhere in the
`certlint` source is the one shown above, in `lint`'s `when 2` branch — a
repository-wide search for `dnsname(` and `.dnsname(` finds no other caller.
That branch already tests `genname.value.is_a? String` and returns before
calling `dnsname` if the test fails, so every value `dnsname` ever receives as
`orig_fqdn` is already a `String`. The `!orig_fqdn.is_a? String` test inside
`dnsname` itself therefore always evaluates false, and `'F: DNSName is not a
string'` (note the lower-case `string`, distinct from the caller's `'F: DNS
Name is not a String'`) is printed by no certificate.

This is a static claim about the call graph, not a runtime behaviour that
needed executing to settle — the guard's condition and its sole caller's guard
are the same test on the same value, one strictly before the other, and
reading both is sufficient.

### Reach

Zero, by construction, for the same reason as CT-010.

### What would fix it

Delete the inner guard (dead code once the sole caller already enforces it),
or, if `dnsname` is meant to be callable independently of `lint` in the
future, keep the guard and add a test that calls it directly with a non-string
argument — which would also serve as a regression check against exactly the
refactor that made the guard dead in the first place.

### What was checked and closed

`certlint`'s test suite is a single 11-line `spec/certlint_spec.rb` that does
not mention `GeneralNames`, `dnsname` or `rfc822name` at all, so it is not a
second caller either. The search covered `lib/`, `bin/` and `spec/`.
