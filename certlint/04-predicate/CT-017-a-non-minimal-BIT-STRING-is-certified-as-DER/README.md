# CT-017 — a non-minimal BIT STRING is certified as DER

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl, a checkout of the tool (the script reads its source) |
| **Cases** | positive/ |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

keyUsage is `03 03 07 06 00` — three unused bits declared, trailing zero octet
retained. X.690 §11.2.2 requires a named-bit-list BIT STRING to drop trailing
zero bits. zlint, x509lint and pkilint all catch this input; `certlint`
reports nothing, and `cablint` reports only two unrelated notices.

The mechanism is not what was first recorded. `CertLint.check_pdu`
(`lib/certlint/certlint.rb:84-88`) *does* test DER conformance, by round trip:
`validator.to_der == content`, else `"E: … is not encoded using DER"`. The
asn1c-generated BIT STRING encoder reproduces the input's unused-bit count and
content octets verbatim rather than applying §11.2.2, so a non-minimal
encoding is a **fixed point of the round trip** and passes:

```
input   0303070600
to_der  0303070600      <- compared against input, equal
```

Fix: canonicalise named-bit-list BIT STRINGs in the re-encode path; the
existing comparison then produces the right message with no further change.
