# PT-029 — a `pkix.` code enforces a rule RFC 5280 does not state and RFC 5480 withdrew

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `05-spec-reading` — Differing analysis of the normative text |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

`KeyUsageValidator` (`certificate_extension.py:600`) reports
`pkix.both_encipheronly_and_decipheronly_ku_set` at ERROR, on
`pdu_class=rfc5280.KeyUsage` — every certificate, every key algorithm, no
scoping and no docstring citation.

The `pkix.` prefix places it on RFC 5280. **RFC 5280 § 4.2.1.3 states no such
prohibition.** Its whole treatment of the two bits is:

> The meaning of the encipherOnly bit is undefined in the absence of the
> keyAgreement bit. When the encipherOnly bit is asserted and the keyAgreement
> bit is also set, the subject public key may be used only for enciphering data
> while performing key agreement.

and the mirror paragraph for `decipherOnly`. Both bits set is semantically contradictory, but § 4.2.1.3 contains no MUST NOT, and `grep -n "encipherOnly\|decipherOnly" rfc5280.txt` returns only those two paragraphs and the two ASN.1 module copies.

The prohibition is **RFC 3279's**, stated three times and scoped each time to
one key-agreement algorithm:

| RFC 3279 | algorithm | text |
|---|---|---|
| § 2.3.3 | Diffie-Hellman | "The keyUsage extension MUST NOT assert both encipherOnly and decipherOnly." |
| § 2.3.4 | KEA | same sentence |
| § 2.3.5 | ECDSA and ECDH | same sentence |

And **RFC 5480, which obsoletes RFC 3279 § 2.3.5 for elliptic curve keys,
drops it**: § 3 says only "it MAY assert either encipherOnly or decipherOnly",
a permission, with no MUST NOT anywhere in the document (`grep` returns four
hits, all permissive).

So pkilint applies, to RSA keys and Ed25519 keys and ML-DSA keys alike, at
ERROR, under an RFC 5280 code, a requirement that RFC 5280 never made, that
RFC 3279 made only for three key-agreement algorithms, and that RFC 5480
withdrew for one of those three.

observed pkix.both_encipheronly_and_decipheronly_ku_set at ERROR for any
algorithm correct the finding belongs on RFC 3279 § 2.3.3/§ 2.3.4 and is
scoped to DH and KEA keys; for EC keys RFC 5480 § 3 supersedes it

algorithm, so nothing here is misreported today; the entry is a source finding
about scope and attribution, not a false positive with victims. It is recorded
because a sweep that reads this site and ports it faithfully would ship the
over-broad version.
