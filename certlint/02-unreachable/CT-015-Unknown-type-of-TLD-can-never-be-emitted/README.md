# CT-015 — `Unknown type of TLD` can never be emitted

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

```ruby
tld = fqdn.split('.').last
tld_type = @iana_tlds[tld]
if tld_type.nil?
  messages << 'E: Unknown TLD'
  return messages
elsif tld_type == :special
  ...
  return messages
elsif tld_type != :public
  messages << 'E: Unknown type of TLD'
end
```

### Why the third branch is unreachable

`@iana_tlds` is populated by exactly two loops in `self.load_domains`
(`iananames.rb:43-78`), and every assignment into the hash is one of two
literal symbols:

```ruby
@iana_tlds[l.split(',').first.downcase] = :public      # line 50, from newgtlds.csv
@iana_tlds[tld] = :public                                # line 60, from root.zone
@iana_tlds[dom] = :special                                # line 74, from special-use-domain.csv
```

No third value is ever assigned. So `tld_type` — read from this hash — can
only ever be `nil` (key absent), `:public`, or `:special`. The method's own
`if`/`elsif` chain tests `nil` first and returns, then tests `:special` and
returns; by the time control reaches `elsif tld_type != :public`, `tld_type`
has already been shown to be neither `nil` nor `:special`, and the hash's own
construction guarantees it is one of exactly those three values — so it must
be `:public`, and `tld_type != :public` is always false. Confirmed by
executing the identical exhaustive-branch shape:

```
$ ruby -e '
h = {"a" => :public, "b" => :special}
["a", "b", "c"].each do |k|
  t = h[k]
  if t.nil?
    puts "#{k}: nil branch"
  elsif t == :special
    puts "#{k}: special branch"
  elsif t != :public
    puts "#{k}: THIRD BRANCH (unreachable)"
  else
    puts "#{k}: (implicit public, no message)"
  end
end'
a: (implicit public, no message)
b: special branch
c: nil branch
```

No key ever reaches the third branch, because the hash construction admits no
value besides `:public`, `:special`, and absence.

### Reach

0 of certificates carry `E: Unknown type of TLD in SAN`, confirmed the same
way as the other three entries.

### Why this is worth recording

Unlike the three `namelint.rb` entries, this is not foreclosed by a different
layer (OpenSSL) — it is dead within `iananames.rb`'s own logic, on the data
`iananames.rb` itself loads. A maintainer fixing this would either delete the
branch or change `self.load_domains` to assign a third symbol for some
category the two-source loader does not currently distinguish (ICANN's
`newgtlds.csv` carries gTLDs that are approved but not yet delegated into the
root zone — commented in the source at line 37-38 — which is plausibly the
category this branch was written for and never wired up).
