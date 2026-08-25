# PT-031 — a keyUsage that will not decode silences every keyUsage check

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `06-parser` — Root cause in the decoder, not in the check |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | `pkilint./repro.sh` (subject + control, same linter, NOTICE floor) |

## Upstream issues, adjudicated

- **#2** — ECDSA signature checks *(open)*
  **related.** #2, #138 and #196 are all itu.invalid_asn1_syntax FATALs raised ON a conformant certificate. This entry is the opposite direction of the same root cause: a decode failure that makes every validator bound to that PDU go silent. Same mechanism, opposite symptom, not filed.
- **#138** — lint_pkix_cert produces ASN.1 errors when certificate is version 1 *(closed)*
  **related.** As #2.
- **#196** — X520CommonNameUnbounded not being applied to non-WebAuth certificate types *(closed)*
  **related.** As #2, and the closest of the three: a mapping that is silently never applied.

## Analysis

A `keyUsage` extension whose BIT STRING is not minimally encoded fails
pkilint's ASN.1 decode. Every validator that reads keyUsage binds
`pdu_class=rfc5280.KeyUsage`, so when that PDU does not materialise **none of
them is ever offered a node** — and the certificate's actual key-usage
violations go unreported.

```
subject   
          OpenSSL:  X509v3 Key Usage: critical / Certificate Sign
          pkilint:  itu.invalid_asn1_syntax (FATAL) ... "Trailing zero bit in
                    named BIT STRING"
                    → no keyUsage-derived finding of any kind

control   a DV certificate whose keyUsage encodes minimally
          OpenSSL:  X509v3 Key Usage: critical / Digital Signature, Key Agreement
          pkilint:  cabf.serverauth.subscriber_discouraged_ku_present (WARNING)
                    → keyUsage machinery ran
```

**observed** — a certificate setting `keyCertSign` receives no finding about
it. **correct** — report the decode failure *and* that keyUsage-dependent
validations were skipped, or read the bits from the raw octets, which OpenSSL
manages from the same input.

**Why High: the subject of the check controls whether the check runs.** An
issuer emitting a trailing zero bit in the named BIT STRING switches off every
keyUsage validation for that certificate. Non-minimal BIT STRING encoding is a
common and easily-produced defect, so this is reachable without intent — and
trivially reachable with it.

**In fairness to pkilint**, it does emit a FATAL naming the extension, so a
consumer treating FATAL as "not fully analysed" is warned that *something*
failed. What is not communicated is the blast radius: nothing says that a
whole family of checks was skipped, and a consumer comparing tools reads the
absence as a missing rule. That distinguishes this from `another entry here`,
where zlint discards its queue silently.

**A second instance, found 2026-08-19 and on a different structure.** Writing
`rfc5280/e_ext_cert_policy_explicit_text_visible_or_bmp_string` turned up 17
certificates that rule reports and pkilint does not, and all 17 carry
`itu.invalid_asn1_syntax (FATAL)` on the `UserNotice` qualifier itself:

```
ASN.1 decoding failure occurred at
"...certificatePolicies.0.policyQualifiers.1.qualifier" with schema
"UserNotice" ...: 'ascii' codec can't decode byte 0xed in position 22
```

`VisibleString` is ISO 646 and cannot hold a byte above `0x7F`, so these
notices are malformed *and* encoded in an arm RFC 5280 prohibits. pkilint's
decode fails, `CertificatePoliciesUserNoticeValidator` is bound by
`pdu_class=rfc5280.UserNotice` and is never offered a node, and the
certificate escapes the check its encoding was going to fail. Same mechanism
as the keyUsage case above; recorded here rather than given a number of its
own, because a number would assert a second defect where there is one defect
with two reachable structures.
