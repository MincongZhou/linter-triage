# XT-013 — the second RSASSA-PSS parameter parse reads the tbsCertificate's bytes with the outer identifier's length

| | |
|---|---|
| **Tool** | `kroeckx/x509lint` at `103c92f` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | fabricated pair differing only in the two signature `AlgorithmIdentifier`s |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

This is in `CheckSigAlg`, not in `CheckPSSSig`, so it is outside the twenty
sites this lane owns. It was found while establishing how `CheckPSSSig` is
reached.

```
$ x509lint XL-T-x5-c-01-both-full.pem          # both copies: 52-octet params
(no algorithm finding)

$ x509lint XL-T-x5-c-01-tbs-full-outer-empty.pem
E: Signature algorithm mismatch               correct
E: Algorithm parameters failed to decode      <- observed; they decode
E: Hash algorithm not allowed                 correct, from the outer copy
```

The tbsCertificate's `RSASSA-PSS-params` in the second file are the same 52
content octets as in the control. There is nothing in that field that failed
to decode.

`checks.c`, `CheckSigAlg`, the `id-RSASSA-PSS` branch. The second parse takes
its data pointer from one identifier and its length from the other:

```c
p = tbs_sig_alg->parameter->value.sequence->data;
pss = d2i_RSA_PSS_PARAMS(NULL, &p,
          sig_alg->parameter->value.sequence->length);
          /*  ^^^^^^^ should be tbs_sig_alg  */
```

When the outer identifier's parameters element is shorter than the tbs one's,
`d2i` is handed a length smaller than the element it is pointed at and fails.
When it is longer, `d2i` succeeds anyway, because the element's own tag and
length bound the read — which is why the defect shows in one direction only.

```c
pss = d2i_RSA_PSS_PARAMS(NULL, &p,
          tbs_sig_alg->parameter->value.sequence->length);
```

## Refuted — the same line is not a heap overread

**Not-a-defect — semantics.** Reading the source, the over-long direction of
XT-013 looks like a buffer overread: a data pointer into one heap allocation,
a length taken from another, and OpenSSL's `ASN1_STRING` data for a
constructed `ASN1_TYPE` is an allocation of exactly the element's own size.

It does not reproduce. A certificate whose tbs parameters are a two-octet
empty SEQUENCE and whose outer parameters are 54 octets, run under an
AddressSanitizer build of this source, produces no report — only the findings
above. `d2i_RSA_PSS_PARAMS` reads what the element's own tag and length claim
and not what the caller's length permits, so a length larger than the element
is simply ignored.

Recorded because the source reads the other way, and a reader who has not run
it will raise it again. No number: a refutation is an examination, and a
number asserts a defect exists.

## Not a defect, and not filed: two `CheckPSSSig` predicates that are narrower than they look

Neither belongs in a defect list; both are worth writing down once so the next
reader does not re-open them.

**`ERR_ALG_PARAMETER_MISSING` on a hash identifier is founded, despite RFC
4055 § 2.1 saying both spellings are legal.** § 2.1 requires implementations
to "accept both NULL and absent parameters as legal and equivalent encodings"
and calls omission "the correct encoding" — and then defines `sha1Identifier`
through `sha512Identifier` as `{ id-shaX, NULL }`, introduced by "the
following algorithm identifiers are used when a NULL parameter MUST be
present". § 3.1 types the `hashAlgorithm` field to those identifiers and § 2.2
types `id-mgf1`'s parameter to them. The leniency is a requirement on a
reader; the identifiers are what a writer emits. The same reading is already
in this tree for `rsaEncryption`.

**`ERR_NOT_ALLOWED_MASK_ALGORITHM` cites BR 7.1.3.2.1 and could not cite RFC
4055.** § 2.2 says only that MGF1 is the one mask generation function this
specification supports — a statement of scope, not a prohibition. A rule
restricting the mask function to MGF1 for every certificate whenever issued
would be asserting a requirement no document states; the Baseline
Requirements' byte-exact encodings are what impose it, and only from
2020-08-20.

## One document-currency observation, for the integrator

the reproduction beside this file's index table at the head of the file lists
`XT-008`, `XT-006` and `XT-009`. Three entries are unreachable from the index
a reader starts at — including `XT-011`, which this lane spent the afternoon
rediscovering.
