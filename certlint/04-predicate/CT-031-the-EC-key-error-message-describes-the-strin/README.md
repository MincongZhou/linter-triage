# CT-031 — the EC key error message describes the string, not the key

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | a real corpus certificate with its subjectPublicKey replaced |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

### The code

```ruby
      begin
        okey = OpenSSL::PKey::EC.new(spki_der)
      rescue ArgumentError => e
        messages << "E: EC public key #{e.message}"
      end
```

### The mechanism

`OpenSSL::PKey::EC.new` given a `String` tries PEM, then DER, and then falls
back to treating the string as the *name of a curve*. When the DER parse
fails, the fallback is what raises — and it raises about the string, not the
key, because a Ruby `String` carrying NUL bytes cannot be handed to
`EC_GROUP_new_by_curve_name` as a C string.

The message is therefore constant. Six `SubjectPublicKeyInfo` shapes were put
through `OpenSSL::PKey::EC.new` directly, each in its own interpreter, and
every one that raises raises the same text — which is the text certlint
interpolates:

| subjectPublicKey | `ArgumentError#message` |
|---|---|
| off-curve point (x=1, y=1 on P-256) | `string contains null byte` |
| first octet 0x09 | `string contains null byte` |
| truncated point | `string contains null byte` |
| empty | `string contains null byte` |
| unrecognized curve OID (1.2.3.4.5) | `string contains null byte` |
| valid P-256 point on a `secp192r1` identifier | `string contains null byte` |

The predicate is right — the site fires exactly when the EC public key does
not decode — so this is a diagnostic defect rather than a wrong verdict, which
is why it is Low. It does mean the message cannot be used to tell *which* of
those five things went wrong, and a reader who takes it literally will go
looking for a NUL byte in a certificate that has none.

```
$ ruby -I lib -I ext bin/certlint CL-T-cl-h-03-ec-bad-first-octet.der
E: EC public key string contains null byte
E: Unable to parse public key
```

**observed** — a message about a NUL byte in a string. **correct** — a message
naming the point encoding that failed to decode.

### Fix

Do not rely on the exception's text. `OpenSSL::PKey::EC.new` reached by way of
`OpenSSL::ASN1` — or the first-octet test RFC 5480 §2.2 states — gives
certlint something to say. At minimum:

```ruby
      rescue ArgumentError
        messages << 'E: EC public key does not decode'
```
