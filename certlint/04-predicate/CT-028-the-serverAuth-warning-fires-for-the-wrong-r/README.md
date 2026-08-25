# CT-028 — the serverAuth warning fires for the wrong reason on almost every certificate it names, and folds in a second misclassification

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | reproduced against real bugzilla incident certificates and zlint's own delegated-OCSP-responder fixtures |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

### The code

```ruby
if eku.empty? && !ku.nil?
  if key.is_a? OpenSSL::PKey::RSA
    if ku.include?('Digital Signature') || ku.include?('Key Encipherment')
      eku << 'tmp-serverauth-usable'
    end
  # ... DSA, EC cases the same shape
elsif eku.empty? && ku.nil?
    eku << 'tmp-serverauth-usable'
end

if eku.include?('tmp-serverauth-usable') || \
    eku.include?('TLS Web Server Authentication') || \
    eku.include?('Any Extended Key Usage') || \
    eku.include?('Netscape Server Gated Crypto') || \
    eku.include?('Microsoft Server Gated Crypto')
  messages << 'I: TLS Server certificate identified'
  if !eku.include?('TLS Web Server Authentication')
    messages << "W: TLS Server certificates must include serverAuth key purpose in extended key usage"
  end
```

`lib/certlint/cablint.rb:408-437` — this lane's sites 7 and 8.

### Two things wrong with the same message, found by running it against the corpus

```
$ cablint bug1391000-crtsh77893170.der
...
I: TLS Server certificate identified
W: TLS Server certificates must include serverAuth key purpose in extended key usage
```

### What was not verified
