# ZT-051 — a do-while walker cannot express an empty `SEQUENCE OF`, and three lints abstain

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `06-parser` — Root cause in the decoder, not in the check |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool |
| **Cases** | positive/ and negative/ |
| **Verified against** | a real Government of Korea GPKI root |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```go
// v3/util/oid.go GetMappedPolicies, and the copy of it inside
// lint_ext_cert_policy_disallowed_any_policy_qualifier.go
for done := false; !done; {
    seq.Bytes, err = asn1.Unmarshal(seq.Bytes, &inner)   // decodes first
    if err != nil {
        return nil, errors.New("policyMap: Could not unmarshal inner sequence.")
    }
    if len(seq.Bytes) == 0 { done = true }               // asks second
    ...
}
```

Handed a `SEQUENCE OF` carrying zero elements, the first `Unmarshal` reads an
empty slice, returns `asn1: syntax error: sequence truncated`, and the walker
reports that it could not unmarshal bytes that decoded cleanly. Three lints
return `fatal` on that path:
`e_ext_cert_policy_disallowed_any_policy_qualifier` through its own copy, and
`e_ext_policy_map_any_policy` and `w_ext_policy_map_not_in_cert_policy`
through `GetMappedPolicies`.

Executed rather than read. The certificatePolicies of is

```
30 0a  30 08  06 04 55 1d 20 00  30 00
SEQUENCE { SEQUENCE { OID 2.5.29.32.0 anyPolicy, SEQUENCE {} } }
```

and stepping the walker over those bytes with the pinned zcrypto gives
`qualifierBytes=3000`, then a `policyQualifiers` sequence whose content is
empty, then `sequence truncated` on the first element. Both Korean GPKI roots
carry it; the control, anyPolicy with one CPS qualifier, passes.

**Reading the bytes through a parser hides this.** `cryptography` re-encodes
the extension as `30 08 30 06 06 04 55 1d 20 00`, dropping the empty
qualifiers sequence, and on those bytes the walker is correct. The defect is
only visible in the DER as issued.

**zlint settles against itself what an empty `SEQUENCE OF` deserves.**
`e_ext_cannot_be_empty_sequence` exists for exactly this violation and returns
`error` — a verdict. On one certificate carrying an empty `policyMappings`,
that lint answers `error` while the two walker lints answer `fatal`. So
`fatal` here is not a house convention for a schema violation, and the three
lints are not three designs agreeing: one walker was copied twice, and the bug
travelled with it.

Correct is `pass` in both. No qualifier is asserted, so none is disallowed; no
`issuerDomainPolicy` is mapped, so none is unasserted.

Fix: test for the end of the sequence before decoding an element — `for
len(seq.Bytes) > 0 { … }` — in `GetMappedPolicies` and in the copy.

**And a gap beside it.** `e_ext_cannot_be_empty_sequence` tests only an
extension's own top-level `SEQUENCE`, so a nested empty `SEQUENCE OF` — the
`policyQualifiers` of case 1 — is reported by nothing.
