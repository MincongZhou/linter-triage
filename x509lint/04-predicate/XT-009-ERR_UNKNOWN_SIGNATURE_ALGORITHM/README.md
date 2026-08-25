# XT-009 — `Unkonwn signature algorithm`

| | |
|---|---|
| **Tool** | `kroeckx/x509lint` at `103c92f` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool |
| **Cases** | positive/ |
| **Verified against** | corpus certificate |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```
E: Unkonwn signature algorithm      <- observed
E: Unknown signature algorithm      <- correct
```

A literal in `messages.c`, in the entry commented
`ERR_UNKNOWN_SIGNATURE_ALGORITHM`, raised from `CheckSigAlg` at
`checks.c:2078` and `2084` and from `CheckSignature` at `2147` when
`OBJ_obj2nid` or `OBJ_find_sigid_algs` cannot resolve the signature algorithm
OID.

No verdict changes — the certificate is reported either way, at the same
severity, from the same branch — which is what puts this at Low. It is
recorded because x509lint has no lint identifiers: the message string *is* the
key any consumer must match on, so correcting the spelling is a breaking
change for anything keyed on it. That is an argument for doing it once and
announcing it, not for leaving it.

Fix: one character in `messages.c`.
