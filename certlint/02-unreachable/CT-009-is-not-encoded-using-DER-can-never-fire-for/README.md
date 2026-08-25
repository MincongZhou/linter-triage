# CT-009 — `is not encoded using DER` can never fire for a name attribute or a policy qualifier

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `02-unreachable` — Checks that cannot fire |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | fabricated input, recipe in the script |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

### The code

`lib/certlint/certlint.rb:85-88` is the DER canonicality check, and it works
by re-encoding through asn1c and comparing against the octets it was handed:

```ruby
der = validator.to_der
unless der == content
  messages << "E: #{pdu} is not encoded using DER"
end
```

That is only a test of the *certificate* if `content` is the certificate's own
octets. It is, at two call sites and not at the others:

| call site | `content` | sees the certificate's octets? |
|---|---|---|
| `certlint.rb:260` `check_pdu(:Certificate, der)` | the file | **yes** |
| `certlint.rb:424` → `asn1ext.rb:24` | `extder.value`, the OCTET STRING's contents | **yes** |
| `namelint.rb:161` `check_pdu(pdu, value.to_der)` | Ruby's re-encoding | no |
| `certificatepolicies.rb:61-66` `q = pqi.value[1].to_der` | Ruby's re-encoding | no |
| `certlint.rb:213/221/229/238/336/341` (`Dss-Parms`, `DomainParameters`, `EcpkParameters`, `ECPoint`, `Dss-Sig-Value`, `ECDSA-Sig-Value`) | Ruby's re-encoding | no |

`value.to_der` on an `OpenSSL::ASN1` object is not the input. Ruby's OpenSSL
binding **normalises** on the round trip, so the non-canonical form is gone
before `check_pdu` ever sees it.

### Reproduction

Run `ruby -I lib -I ext CL-T-cl-g-03-repro.rb` from the certlint checkout.

```
the certificate's own octets : 1381024553      # PrintableString "ES",
what namelint passes on      : 13024553        #   long-form length, then not

observed  check_pdu(:X520countryName, value.to_der) -> []
correct   check_pdu(:X520countryName, raw)          -> ["E: X520countryName is not encoded using DER"]
```

X.690 §8.1.3.3: the definite short form is used when the length is under 128,
so `81 02` where `02` fits is legal BER and is not DER. The check exists to
say so and cannot.

The script also prints the round trip on three encodings, which is the
mechanism rather than the symptom:

```
long-form length where short fits  1381024553 -> 13024553  NORMALISED
BOOLEAN TRUE encoded 0x01          010101     -> 0101ff    NORMALISED
non-minimal BIT STRING padding     030201fe   -> 030201fe  preserved
```

Two of the three DER canonicality defects certlint reports elsewhere are
erased on the way in. The third survives, which is why the defect is invisible
from the outside: the check *does* still fire, on extensions and on the
certificate, so nobody looking at output would guess a whole class of PDUs is
exempt.

### Consequence beyond this one message

The same `content` reaches all eighteen checks in `check_pdu`, so for a name
attribute or a policy qualifier every one of them is asked about Ruby's
re-encoding rather than the certificate. The constraint checks and the string
checks are mostly unaffected — normalisation changes lengths and BOOLEANs, not
character data — but any future check in that function about *how* the value
is encoded inherits the exemption silently.

### Suggested fix

Carry the original octets alongside the parsed object.
`OpenSSL::ASN1.traverse` already yields the offset and header length of every
element, which is enough to slice the input; `namelint.rb` has the whole
`Name` DER in scope at `name.to_der` and could index into it. Failing that,
the honest short fix is to skip the DER comparison when the caller cannot
supply original octets, so the check does not silently certify what it never
examined.

Its own DER canonicality rules read the certificate's octets directly through
`decode::tlv` and `decode::tbs`, which is the arrangement this entry
recommends.

### CT-009, re-executed by the integrator

The claim is that Ruby's OpenSSL normalises the round trip, so a check handed
`value.to_der` is handed the canonical form of the bytes it exists to judge.
Run against the vendored checkout's own Ruby (3.3.8):

```ruby
raw = ["0c8103616263"].pack("H*")          # UTF8String "abc", long-form length
v   = OpenSSL::ASN1.decode(raw)
raw == v.to_der                            #=> false
v.to_der.unpack1("H*")                     #=> "0c03616263"

OpenSSL::ASN1.decode(["010101"].pack("H*")).to_der.unpack1("H*")
                                           #=> "0101ff"
```

Both of the non-DER encodings the check exists to catch — a long-form length
where the short form fits, and a `BOOLEAN` whose contents octet is not `0xFF`
— are gone before the comparison happens. `raw == v.to_der` is false precisely
because `to_der` fixed them.

So for every caller that passes `value.to_der`, the test compares DER against
DER. It cannot fail, and certlint reports DER conformance for name attributes
and policy qualifiers that it never verified. That is the severity table's own
definition of **High**: a check that reports conformance it did not establish.

The lane's reading was right and this adds nothing to it except that the
mechanism now has its own transcript, on the same Ruby the tool runs under.
