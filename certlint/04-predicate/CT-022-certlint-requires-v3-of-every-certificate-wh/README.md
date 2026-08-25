# CT-022 — certlint requires v3 of every certificate, where RFC 5280 requires it only with extensions

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl, a checkout of the tool (the script reads its source) |
| **Cases** | positive/ and negative/ |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

`lib/certlint/certlint.rb:356-360` decides the version from `cert.version`
alone:

```ruby
if cert.version > 2
  messages << 'E: Invalid certificate version'
elsif cert.version < 2
  messages << 'E: Old certificate version (not X.509v3)'
end
```

Neither limb consults the extension list. RFC 5280 §4.1.2.1 makes the v3
requirement **conditional**:

> When extensions are used, as expected in this profile, version MUST be 3
> (value is 2). If no extensions are present, but a UniqueIdentifier is
> present, the version SHOULD be 2 (value is 1); however, version MAY be 3. If
> only basic fields are present, the version SHOULD be 1 (the value is omitted
> from the certificate as a default value); however, the version MAY be 2 or 3.

So for a certificate with no extensions, v1 is what the clause **recommends**,
and certlint reports an error for following the recommendation. The first limb
is correct — there is no version above 3 — which is what makes this a missing
condition rather than a misread clause.

The `allUIDv2.pem` case is the sharpest single example: v2, unique identifiers
present, no extensions — precisely the shape the clause's second sentence
describes and recommends v2 for.

```ruby
elsif cert.version < 2 && cert.extensions.any?
```

A tool wanting to say something about the v1 roots regardless should say it as
a notice, since RFC 5280 states no requirement they breach.
