# CT-033 — DSA `keyUsage` uses one allow-list for every role

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

`lib/certlint/extensions/keyusage.rb:57-66`:

```ruby
elsif pk.is_a? OpenSSL::PKey::DSA
  allowed = [
    'Digital Signature',
    'Non Repudiation',
    'Certificate Sign',
    'CRL Sign'
  ]
  if v.any? { |u| !allowed.include? u }
    messages << "E: Unallowed key usage for DSA public key (#{(v-allowed).join(', ')})"
  end
```

One `allowed` list, applied to every certificate carrying a DSA key regardless
of role.

### What the citation actually states

RFC 3279 § 2.3.2 gives two lists, in two paragraphs:

> If the keyUsage extension is present in an end entity certificate which
> conveys a DSA public key, any combination of the following values MAY be
> present: digitalSignature; nonRepudiation;
>
> If the keyUsage extension is present in a CA or CRL issuer certificate
> which conveys a DSA public key, any combination of the following values
> MAY be present: digitalSignature; nonRepudiation; keyCertSign; and cRLSign.

`allowed` in the code is the *second* paragraph's list, used for both. An
end-entity DSA certificate asserting `keyCertSign` or `cRLSign` — which §
2.3.2's first paragraph does not permit — is silently accepted, because those
two bits are in the list the code checks against regardless of role.

### What would fix it

Two lists, matching the RFC's two paragraphs, selected by whether `cert.ca?`
(or the equivalent role determination `certlint.rb` already carries) is true.

### How this lane ported it

`rfc3279/e_dsa_allowed_ku_ee` and `rfc3279/e_dsa_allowed_ku_ca`, the same
two-rule split `e_rsa_allowed_ku_ee`/`e_rsa_allowed_ku_ca` already use for
RSA.
