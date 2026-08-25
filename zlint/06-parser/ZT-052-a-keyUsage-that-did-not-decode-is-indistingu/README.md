# ZT-052 — a `keyUsage` that did not decode is indistinguishable from one asserting no bits

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `06-parser` — Root cause in the decoder, not in the check |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl, python3 |
| **Cases** | positive/ and negative/ |
| **Verified against** | four real certificates from Mozilla bug 1742195, four trust-store intermediates, plus a fabricated control |

## Upstream issues, adjudicated

- **#443** — Lint to prohibit anyEKU in Subscriber Certs after 2020-07-01 *(open)*
  **unrelated.** Feature request for an anyEKU prohibition lint.
- **#553** — Revisiting `e_key_usage_and_extended_key_usage_inconsistent` lint and RFC interpretation. *(open)*
  **unrelated.** The keyUsage/EKU consistency debate; matched on the word keyUsage.
- **#583** — Discussion: Consider how proposed CA/B Forum SCWG profiles will be linted *(open)*
  **unrelated.** A design discussion about SCWG profiles.
- **#712** — Lint Coverage of SMIME BRs version 1.0.0 *(open)*
  **unrelated.** An S/MIME BR coverage checklist.

## Analysis

```
06 03 55 1d 0f   01 01 ff   04 01 d4
OID 2.5.29.15    critical   OCTET STRING { d4 }
```

one raw byte where a DER `BIT STRING` belongs — the `03 02` header is absent.
zcrypto handles that in `x509/x509.go`:

```go
case 15:
    var usageBits asn1.BitString
    _, err := asn1.Unmarshal(e.Value, &usageBits)
    if err == nil {
        ...
        out.KeyUsage = KeyUsage(usage)
        continue
    }
    // no else: out.KeyUsage keeps its zero value, and nothing records why
```

Executed against the pinned zcrypto rather than inferred: `ParseCertificate`
returns a **nil error**, the extension stays in `c.Extensions`, and
`c.KeyUsage` is `0b0`. **There is no third state**, and the neighbouring
branch shows the omission is not a house style: `case 19` sets
`BasicConstraintsValid` so that basicConstraints has one. `keyUsage` has no
equivalent, so "asserted no bits" and "could not be read" are the same value.

Six error-floor lints then state facts about bits nobody read:

| lint | what it asserts |
|---|---|
| `e_ca_key_usage_missing` | the extension is absent — it is present and critical |
| `e_ca_crl_sign_not_set` | `cRLSign` is unset |
| `e_ca_key_cert_sign_not_set` | `keyCertSign` is unset |
| `e_ext_key_usage_without_bits` | no bits are set |
| `e_key_usage_incorrect_length` | a length claim about bytes it did not parse |
| `e_sub_cert_not_is_ca` | likewise |

`e_ca_key_usage_missing` is the plainest. Its `Description` is "Root and
Subordinate CA certificate keyUsage extension MUST be present" and its
`Execute` is `if c.KeyUsage != x509.KeyUsage(0) { Pass } else { Error }`, so
it reports a present extension as absent whenever the value did not decode.

**The control shows the two are indistinguishable in the output.** A
fabricated CA with a well-formed, genuinely empty `keyUsage` (`03 02 07 00`)
draws the same verdicts. The single place the distinction survives is
`e_incorrect_ku_encoding`, which returns `fatal` on the malformed certificate
and `error` on the control — so zlint holds the information and the other
lints do not consult it.

**This is the shape [README.md](README.md#severity) calls the serious one**,
and it is the same shape as [`another entry here`](pkilint.md#pk-003) in
another tool, sharpened: there a `keyUsage` that will not decode *silences*
every keyUsage check, here it *inverts* six of them into confident assertions
about the certificate's content. An issuer emitting a malformed `keyUsage`
therefore does not lose the checks; it gains six findings that describe a
value nobody read.

Fix: give zcrypto a `KeyUsageValid` flag mirroring `BasicConstraintsValid`,
set it in the `case 15` branch, and gate the keyUsage lints on it. Failing
that, `e_ca_key_usage_missing` should test `util.IsExtInCert(c,
util.KeyUsageOID)` rather than `c.KeyUsage != 0`, which is the presence
question it documents.
