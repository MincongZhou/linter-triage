# ZT-012 — the MRSP ECDSA encoding lints are dated five years late

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool |
| **Cases** | positive/ and negative/ |
| **Verified against** | real pair from CA compliance bugs |

## Upstream issues, adjudicated

- **#539** — Lints with wrong references (e.g. CABF when really RFC) *(open)*
  **related.** The meta-issue's checklist names e_mp_ecdsa_pub_key_encoding_correct, but for re-categorisation from mozilla to cabf_br. This entry is about its effective date, which that move would not fix.

## Analysis

Observed `NE` for notBefore 2022-12-07; correct `error`.

`e_mp_ecdsa_signature_encoding_correct` and
`e_mp_ecdsa_pub_key_encoding_correct` both carry `EffectiveDate:
util.MozillaPolicy30Date`, which `util/time.go:79` sets to **2025-03-15**. The
clause they enforce — MRSP § 5.1.2, the exact hex-encoded
`AlgorithmIdentifier` bytes for ECDSA keys and signatures — first appears in
**MRSP 2.7, effective 2020-01-01**.

The correct constant is already in the file and already in use.
`util/time.go:78` defines `MozillaPolicy27Date = 2020-01-01`, and the two
RSA-PSS lints drawn from **the same section of the same document** —
`e_mp_pss_parameters_encoding_correct` and `e_mp_rsassa-pss_in_spki` — carry
it. One half of § 5.1.2 is dated to when it was published and the other half
to five years later.

What MRSP 3.0 actually changed there was to **add the P-521 arm**, to both the
SPKI and the signature clause. The P-256 and P-384 arms are word for word what
2.7 published. So 2025-03-15 is right for a third of the requirement and five
years late for the rest — the shape §9's single-`Gate` item describes from the
other side: one lint, two effective dates, and no way to say so.

Found from a CA's own incident. WISeKey issued
`positive/ZT-012-p256-key-signed-sha384-2022.pem` deliberately on 2022-12-07
as a negative test of a new EJBCA deployment, expecting its linters to reject
it — bug 1804587, whose report states zlint is what caught it at the time. It
has a 70-octet signature, so a P-256 signing key, under an `ecdsa-with-SHA384`
identifier where § 5.1.2 requires `300a06082a8648ce3d040302`. Today's zlint
returns `NE` on that same certificate.

Fix: gate both lints at `MozillaPolicy27Date`, and apply the P-521 arm from
`MozillaPolicy30Date`.
