# CT-012 — `is using deprecated VideoexString` can never be emitted

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

`lib/certlint/namelint.rb:192-195`, inside `NameLint.lint`'s per-attribute
`case tag` block:

```ruby
when 21 # Videotex
  value = value.value
  check_padding = true
  attr_messages << "W: #{attrname} is using deprecated VideoexString"
```

`tag` comes from `value.tag` on an `OpenSSL::ASN1::ASN1Data` produced by
`OpenSSL::ASN1.decode(name.to_der)` at line 129 — and `name`, the parameter to
`NameLint.lint`, is not raw DER: it is `cert.subject`, already an
`OpenSSL::X509::Name` built by OpenSSL's own `d2i_X509_NAME` when
`certlint.rb:350` calls `OpenSSL::X509::Certificate.new(der)`. `NameLint.lint`
never runs on a certificate that call does not return: `certlint.rb:351-353`
rescues `OpenSSL::X509::CertificateError` and returns `'F: Unable to parse
Certificate'` immediately, before `NameLint.lint(cert.subject)` at line 381 is
ever reached.

### Why `d2i_X509_NAME` never yields a VideotexString attribute value

```
$ ruby -Ilib -Iext -e '
require "openssl"
der = File.binread("/tmp/patched_videotex.der")   # one tag byte changed, same length
begin
  cert = OpenSSL::X509::Certificate.new(der)
  puts "parsed"
rescue => e
  puts "#{e.class}: #{e.message}"
end'
OpenSSL::X509::CertificateError: PEM_read_bio_X509: no start line (Expecting: CERTIFICATE)
```

(The DER-reading path raises the same `CertificateError` family; the message
above is from the PEM-guessing entry point `bin/cablint` actually uses, which
falls through to the DER path and fails there. Constructing the isolated
`OpenSSL::X509::Name` directly from the same bytes, bypassing the PEM/DER
guess, gives the underlying cause:)

```
$ ruby -Ilib -Iext -e '
require "openssl"
seq = ...  # AttributeTypeAndValue SEQUENCE, tag 21 (Videotex), OID 2.5.4.3
n = OpenSSL::X509::Name.new(OpenSSL::ASN1.decode(seq.to_der))'
OpenSSL::X509::NameError: nested asn1 error
```

`OpenSSL::X509::Name`'s underlying ASN.1 template — the same one
`d2i_X509_NAME` uses when parsing a full certificate's subject and issuer
fields — accepts a fixed set of string tags for a name attribute's value and
`VideotexString` (21) is not one of them. A certificate encoding any name
attribute with tag 21 therefore fails whole-certificate parsing before either
`bin/cablint` or `bin/certlint` reaches `NameLint.lint` at all, and is
reported as `F: Unable to parse Certificate` (or, via `bin/cablint`'s earlier
`PEMLint` stage, an equivalent decode failure) — never as the deprecation
warning at line 195.

### Why this is worth recording
