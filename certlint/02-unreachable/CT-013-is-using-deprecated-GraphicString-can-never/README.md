# CT-013 — `is using deprecated GraphicString` can never be emitted

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

Identical mechanism to CT-012, one tag over.
`lib/certlint/namelint.rb:199-202`:

```ruby
when 25 # Graphic
  value = value.value
  check_padding = true
  attr_messages << "W: #{attrname} is using deprecated GraphicString"
```

Executed the same way, substituting tag 25 (`GraphicString`) for 21:

```
$ ruby -Ilib -Iext -e '
require "openssl"
seq = ...  # AttributeTypeAndValue SEQUENCE, tag 25 (Graphic), OID 2.5.4.3
OpenSSL::X509::Name.new(OpenSSL::ASN1.decode(seq.to_der))'
OpenSSL::X509::NameError: nested asn1 error
```
