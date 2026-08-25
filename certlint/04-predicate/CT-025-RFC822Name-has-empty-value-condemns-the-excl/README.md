# CT-025 — `RFC822Name has empty value` condemns the excludedSubtree that excludes all email

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl, a checkout of the tool (the script reads its source) |
| **Cases** | positive/ |
| **Verified against** | CCADB trust-store intermediate |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```
$ certlint positive/CT-025-empty-rfc822-excluded.der
E: RFC822Name has empty value
```

The certificate is a name-constrained sub-CA of the Academy of Athens. Its
nameConstraints read:

```
Permitted:  DNS:academyofathens.gr
            DirName:C = GR, L = Athens, O = Academy of Athens
Excluded:   email:
            IP:0.0.0.0/0.0.0.0
            IP:0:0:0:0:0:0:0:0/0:0:0:0:0:0:0:0
```

Those three exclusions are one statement: this CA issues no email certificates
and no IP-address certificates. RFC 5280 §4.2.1.10 makes rfc822Name matching a
suffix comparison, so the empty suffix matches every mail address — it is the
only way to say it. **certlint accepts the two all-address IP exclusions on
the adjacent lines and rejects the email one**, which is the clearest evidence
available that the empty rfc822Name is not the outlier here.

**The flag that would fix this is already in scope and already used twice.**
`lib/certlint/generalnames.rb:73-78`:

```ruby
def self.rfc822name(orig_addr, is_constraint = false)
  messages = []
  if orig_addr.nil? || orig_addr.empty?
    messages << 'E: RFC822Name has empty value'
    return messages # Fatal to this entry
  end
```

`is_constraint` exists precisely because a constraint is not a mailbox. Line
91 suppresses `E: RFC822Name without @` for a constraint, because
`example.com` means "every mailbox on that host"; line 103 suppresses `E:
RFC822Name domain must not start with.`, because `.example.com` is RFC 5280's
own worked example. Both work — run against the function directly, the three
non-empty constraint forms are all accepted:

```
""                   E: RFC822Name has empty value
"example.com"        accepted
".example.com"       accepted
"user@example.com"   accepted
```

The empty-value branch above them is the one place the flag is not consulted.

**`dnsname` at `generalnames.rb:159` has the same shape** — its empty check
also precedes every `is_constraint` test — and a zero-length dNSName
excludedSubtree is equally standard, so the fix belongs in both.

**Medium.** It is a false positive that condemns a conformant certificate, and
it condemns precisely the CAs that took the trouble to constrain themselves.
Three of the five are in the CCADB trust store.

**Fix** — consult the flag that is already there:

```ruby
if orig_addr.nil? || (orig_addr.empty? && !is_constraint)
```
