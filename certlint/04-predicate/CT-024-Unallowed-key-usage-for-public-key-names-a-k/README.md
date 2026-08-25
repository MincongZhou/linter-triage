# CT-024 — `Unallowed key usage for … public key` names a key usage that does not exist

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl, python3, a checkout of the tool (the script reads its source) |
| **Cases** | positive/ and negative/ |
| **Verified against** | one zlint fixture, one real incident certificate |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```
$ certlint positive/CT-024-keyusage-no-bits.der        # keyUsage BIT STRING, every bit clear
E: Unallowed key usage for RSA public key (....)

$ certlint positive/CT-024-keyusage-undecodable.der    # keyUsage extnValue is not a BIT STRING
E: Unallowed key usage for RSA public key (.)
```

Neither certificate asserts a key usage outside the RSA set. The first asserts
none at all; the second carries an extnValue that does not decode —
`cryptography` refuses the whole extension list on it.

**The check reads the rendered extension rather than the decoded bits.**
`lib/certlint/extensions/keyusage.rb:29`:

```ruby
v = OpenSSL::X509::Extension.new('2.5.29.15', content, critical)
      .value.split(',').map(&:strip)
```

OpenSSL prints one dot for each byte it has no name for, so both malformed shapes arrive as strings of dots, and the allow-list test twenty lines down — `if v.any? { |u| !allowed.include? u }` — is true for them. Executed, the three shapes render:

```
digitalSignature   .value => "Digital Signature"
all bits clear     .value => "...."
not a BIT STRING   .value => "..."
```

**Fix** — decide the two shapes before the allow-list, from the decoded
extension rather than from its rendering:

```ruby
asn1 = OpenSSL::ASN1.decode(content) rescue nil
if asn1.nil? || !asn1.is_a?(OpenSSL::ASN1::BitString)
  messages << 'E: keyUsage is not a valid BIT STRING'
  return messages
end
if v.empty? || v.all? { |u| u =~ /\A\.+\z/ }
  messages << 'E: keyUsage asserts no bits'
  return messages
end
```

The second test carries most of the value on its own: a rendering that is dots
and nothing else is never a key usage.
