# ZT-042 — `e_invalid_legacy_spki_algoid` runs the other lint's allow-list

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | zlint's `sm1_alg_mld44_eff1_pqf0.pem`, with its `sm1_alg_p224_eff1_pqfx.pem` as the control |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

S/MIME BR § 7.1.3.1 opens *"The following requirements apply to the
subjectPublicKeyInfo field within a Certificate. No other encodings are
permitted"* and then gives the permitted `AlgorithmIdentifier` encodings
byte-for-byte. **v1.0.11, effective 2025-08-22, added ML-DSA and ML-KEM** to a
list that until then held six: RSA, P-256, P-384, P-521, Ed25519, Ed448.

zlint answers the two editions with two lints on complementary windows, which
is the right shape:

| lint | window | list |
|---|---|---|
| `e_invalid_legacy_spki_algoid` | 2023-09-01 → 2025-08-22 | six |
| `e_invalid_spki_algoid` | 2025-08-22 → | twelve |

**Both execute the twelve.** `lint_invalid_legacy_spki_alogid.go` declares its
own six-entry list and its own constructor, then registers the other file's:

```go
lint_invalid_legacy_spki_alogid.go:44    Lint: NewInvalidSPKIAlgoId,
lint_invalid_spki_algoid.go:43           Lint: NewInvalidSPKIAlgoId,
```

`NewInvalidLegacySPKIAlgoId` is declared six lines below the registration that
should name it and **has no callers anywhere in the tree** — grep, then
confirmed by running the lint. It is dead code, and with it the six-entry list
it returns.

So for the twenty-four months this lint alone judges, an ML-DSA or ML-KEM key
in an S/MIME certificate is accepted by the only check that would have caught
it. The file's own header comment states the intent the wiring defeats:
*"Since a few PQC algorithms have been added by SCMxx to the initial list of
allowed algorithms in BR 1.0.0, we perform this check taking into account the
issuance date (notBefore) of the certificate."* Two lints with identical
behaviour take no account of the issuance date at all.

**Read, then executed** — the claim is about control flow, so grep is not the
evidence. On zlint's own `sm1_alg_mld44_eff1_pqf0.pem`, ML-DSA-44 issued
2025-07-22 and so inside the window:

```
e_invalid_legacy_spki_algoid: pass
```

and on the control `sm1_alg_p224_eff1_pqfx.pem`, P-224 issued 2025-07-29, a
curve outside *both* lists:

```
e_invalid_legacy_spki_algoid: error
  Invalid Subject Public Key Algorithm Identifier: 301006072A8648CE3D020106052B81040021
```

The control is what makes the first line evidence rather than silence: the
lint is running, and it is running the wrong list.

**Its own test file asserts the defective behaviour**, which is why the suite
is green. Six cases named `*_pqf0` — the family's own marker for *issued
before the PQC effective date* — expect `Pass` where the pre-1.0.11 list gives
`Error`:

```go
{input: "smime/sm1_alg_mld44_eff1_pqf0.pem", want: lint.Pass},
```

Correcting the wiring without correcting those six turns the suite red, so the
fix is one line in the lint and six in the test.

themselves. Measured directly rather than through either tool: of **472**
certificates carrying `id-kp-emailProtection` and issued inside the window,
eight have an `AlgorithmIdentifier` outside the pre-1.0.11 six, and zlint
reports two of them — the P-224 and the GOST fixtures, which are outside the
twelve as well. The other six are the ML-DSA and ML-KEM ones.

Fix: `lint_invalid_legacy_spki_alogid.go:44`, `Lint: NewInvalidSPKIAlgoId` →
`Lint: NewInvalidLegacySPKIAlgoId`.

*(The filename's `alogid` is a typo for `algoid` and is not part of this
report — nothing reads it.)*
