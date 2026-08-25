# CT-032 — the example-domain test is anchored at the wrong end

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

Found by the integrator while writing the rule that answers this site
(`rfc2606/n_dnsname_under_example_domain`), which is where a lane's deferral
usually pays: the site was read twice, by two people, and the second reading
had to build the predicate rather than describe it.

### The code

```ruby
@example_domains = ["example.com", "example.net", "example.org"]
...
if ('.' + fqdn).end_with?(*@example_domains)
  messages << 'N: FQDN under example domain'
```

The dot is prefixed to the **name** rather than to each **domain**. That
anchors the start of the whole string and nothing else, so the test is a bare
suffix test and reports any name whose final characters happen to spell a
reserved one.

### Observed and correct

```
$ ruby -e 'ex=["example.com","example.net","example.org"]
           %w[example.com notexample.com www.notexample.com myexample.org
              example.company.com].each { |f|
             puts format("%-22s -> %s", f, ("."+f).end_with?(*ex)) }'
example.com            -> true
notexample.com         -> true     # observed; correct is false
www.notexample.com     -> true     # observed; correct is false
myexample.org          -> true     # observed; correct is false
example.company.com    -> false
```

`notexample.com`, `www.notexample.com` and `myexample.org` are names IANA has
never reserved. RFC 2606 § 3 reserves three names, not three suffixes.

### The fix

One line: prefix the dot to the domains, and test equality separately.

```ruby
if @example_domains.any? { |d| fqdn == d || fqdn.end_with?('.' + d) }
```

### What was not verified
