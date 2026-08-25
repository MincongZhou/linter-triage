# ZT-088 — `n_ecdsa_ee_invalid_ku` reports `encipherOnly`/`decipherOnly` as invalid even when RFC 5480 permits them

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

The check is a `Notice`, not a conformance verdict, so nothing downstream
treats its output as misissuance; it misleads a reader about which key usages
RFC 5480 actually permits without changing whether a certificate passes or
fails anything.

**The mechanism, added by the integrator: the lint quotes its own citation and
stops one sentence short of the counter-text.** Its source comment reproduces
the first paragraph of RFC 5480 § 3 verbatim —

> If the keyUsage extension is present in an End Entity (EE) certificate that
> indicates id-ecPublicKey in SubjectPublicKeyInfo, then any combination of the
> following values MAY be present: digitalSignature; nonRepudiation; and
> keyAgreement.

— and builds `allowedKUs` from exactly those three. The very next sentence of
the clause, not quoted and not implemented, is:

> If the EE certificate keyUsage extension asserts keyAgreement, then it MAY
> assert either encipherOnly or decipherOnly.

So the check contradicts the document it cites, and the contradicting text is
one line below the text it copied. The one-line fix is to admit `encipherOnly`
and `decipherOnly` when `keyAgreement` is asserted. The CA paragraph above it
has the same allowance plus a SHOULD NOT for the `keyCertSign`/`cRLSign` case,
so a fix should look at whether the CA-side sibling needs the same treatment.

```

```

```
{"n_ecdsa_ee_invalid_ku":{"result":"info","details":"Certificate had unexpected key usage(s): KeyUsageEncipherOnly"}}
{"n_ecdsa_ee_invalid_ku":{"result":"info","details":"Certificate had unexpected key usage(s): KeyUsageDecipherOnly"}}
{"n_ecdsa_ee_invalid_ku":{"result":"info","details":"Certificate had unexpected key usage(s): KeyUsageDecipherOnly"}}
```

Correct: all three should `pass`. Each of the three certificates asserts
`keyAgreement` alongside the flagged bit.

**Mechanism.** `v3/lints/rfc/lint_ecdsa_ee_invalid_ku.go`'s `Execute` builds
`allowedKUs` from exactly three bits — `digitalSignature`,
`contentCommitment`, `keyAgreement` — and flags any other set bit as
unexpected, unconditionally. The lint's own cited clause, RFC 5480 § 3, is
conditional:

> If the EE certificate keyUsage extension asserts keyAgreement, then it MAY
> assert either encipherOnly or decipherOnly.

`encipherOnly`/`decipherOnly` are permitted values of the *same* clause the
check claims to answer, contingent on `keyAgreement` also being set — which
every one of the three reproduction certificates satisfies. `allowedKUs` has
no entry for either bit under any condition, so the check treats them as
forbidden always rather than forbidden-unless-paired-with-`keyAgreement`.

**One-line fix.** Add `KeyUsageEncipherOnly` and `KeyUsageDecipherOnly` to
`allowedKUs`, guarded on `KeyUsageKeyAgreement` also being set in `c.KeyUsage`
— permit either bit only when `keyAgreement` is present, matching the clause's
own conditional rather than an unconditional list.

## What was not verified
