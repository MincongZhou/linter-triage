# CT-014 — `is using deprecated GeneralString` can never be emitted

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

- **#3** — TeletexString/T61String *(open)*
  **related.** Same check.

## Analysis

Same mechanism again, tag 27. `lib/certlint/namelint.rb:206-209`:

```ruby
when 27 # General
  value = value.value
  check_padding = true
  attr_messages << "W: #{attrname} is using deprecated GeneralString"
```

```
$ ruby -Ilib -Iext -e '
require "openssl"
seq = ...  # AttributeTypeAndValue SEQUENCE, tag 27 (General), OID 2.5.4.3
OpenSSL::X509::Name.new(OpenSSL::ASN1.decode(seq.to_der))'
OpenSSL::X509::NameError: nested asn1 error
```
