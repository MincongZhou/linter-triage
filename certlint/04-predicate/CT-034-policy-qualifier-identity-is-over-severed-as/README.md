# CT-034 — policy qualifier identity is over-severed as an error

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

### The code

`lib/certlint/extensions/certificatepolicies.rb:107-109`:

```ruby
else
  messages << 'E: Bad policy qualifier id'
end
```

The `else` arm of a `case qualid` over the two RFC 5280-defined qualifier
OIDs, reached whenever a `PolicyQualifierInfo`'s `policyQualifierId` is
neither.

### What the citation actually states

RFC 5280 § 4.2.1.4: "this profile RECOMMENDS that policy information terms
consist of only an OID. Where an OID alone is insufficient, this profile
**strongly recommends** that the use of qualifiers be limited to those
identified in this section." RECOMMENDS and "strongly recommends," not MUST —
and the ASN.1 itself defines `qualifier ANY DEFINED BY policyQualifierId`, an
explicitly open-ended type. Nothing in § 4.2.1.4 states a prohibition on a
third qualifier identifier.

### What would fix it

Downgrade the message to a warning, or cite a document that states the
prohibition as a MUST if one exists and was missed here.

### How this lane handled it

Ported as `rfc5280/w_ext_cert_policy_qualifier_id_unrecognized`, warning
severity, implementing § 4.2.1.4's own word rather than certlint's.
