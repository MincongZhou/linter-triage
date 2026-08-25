# XT-003 — `ERR_GEN_NAME_TYPE` is unreachable: OpenSSL's own decoder fixes the field it tests

| | |
|---|---|
| **Tool** | `kroeckx/x509lint` at `103c92f` |
| **Group** | `02-unreachable` — Checks that cannot fire |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | reproduction: the reproduction beside this file, executed against OpenSSL 3.5.6 |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

### The code

`checks.c:919`–`936`, `CheckGeneralNameType`, called once per `GeneralName`
from both `CheckSAN` (`checks.c:1127`, subjectAltName) and `CheckCRL`
(`checks.c:1226`, crlDistributionPoints fullName):

```c
static void CheckGeneralNameType(GENERAL_NAME *name)
{
	int type;
	ASN1_STRING *s = GENERAL_NAME_get0_value(name, &type);
	if (type == GEN_DNS || type == GEN_EMAIL || type == GEN_URI)
	{
		if (s->type != V_ASN1_IA5STRING)
		{
			SetError(ERR_GEN_NAME_TYPE);
		}
	}
	else if (type == GEN_IPADD)
	{
		if (s->type != V_ASN1_OCTET_STRING)
		{
			SetError(ERR_GEN_NAME_TYPE);
		}
	}
}
```

The claim is that a `dNSName`/`rfc822Name`/`uniformResourceIdentifier` entry
could decode with an `ASN1_STRING` whose own `->type` field is something other
than `V_ASN1_IA5STRING`, or an `iPAddress` entry with something other than
`V_ASN1_OCTET_STRING`.

### Why the claim is false, and how that was settled

This is a claim about OpenSSL's decoder's behaviour, so it is settled by
running OpenSSL's decoder, not by reading the header. `GeneralName` is an
ASN.1 `CHOICE`, and OpenSSL decodes each of `dNSName`, `rfc822Name` and
`uniformResourceIdentifier` as an implicitly-tagged `IA5String` through one
shared union member (`GENERAL_NAME_get0_value`'s own source returns `a->d.ia5`
for all three, per OpenSSL's `v3_genn.c`). With implicit tagging the content
octets are interpreted as the compile-time-declared type regardless of what
the wire tag was — there is no code path by which the decoder can hand back an
`ASN1_STRING` for one of these three alternatives whose `->type` is anything
but `V_ASN1_IA5STRING`. The `iPAddress` alternative decodes through the same
machinery to `V_ASN1_OCTET_STRING`, unconditionally.

`XL-T-x5-h-01-gen-name-type.c` builds three raw DER `GeneralNames` SEQUENCEs
by hand — a normal `dNSName`, one whose content is a non-ASCII byte (`0xFF`),
and one with empty content — and decodes each with `d2i_GENERAL_NAMES`
followed by `GENERAL_NAME_get0_value`, exactly the call `CheckGeneralNameType`
makes:

```
Case 1: normal dNSName, tag=0x82 content=0x61 ('a')
  ASN1_STRING->type=22 (V_ASN1_IA5STRING=22)
Case 2: dNSName, tag=0x82 content=0xFF (non-ASCII)
  ASN1_STRING->type=22 (V_ASN1_IA5STRING=22)
Case 3: dNSName, tag=0x82 empty content
  ASN1_STRING->type=22 (V_ASN1_IA5STRING=22)
```

Non-ASCII content and empty content are exactly the shapes a certificate can
carry to try to make `s->type` diverge, and neither does — the field is set by
the template, not the bytes. The `iPAddress` companion program shows the same
result for `V_ASN1_OCTET_STRING` on both a 4-octet and a malformed 3-octet
address. Both branches of `CheckGeneralNameType` are therefore unreachable
through the only call path that exists: `X509_get_ext_d2i` →
`d2i_GENERAL_NAMES` → `GENERAL_NAME_get0_value`.

### Why High

The check can never fire, which is the first of the three High conditions in
the gap-reporting skill's severity table. It costs nothing today — the
population it would have reported is empty by the same construction that
disables it — but it is not a cosmetic slip: a reader of x509lint's output who
sees no `ERR_GEN_NAME_TYPE` finding has learned nothing, because the finding
was never reachable, and a maintainer extending the function on the belief
that the guard does something inherits a check that cannot be exercised by any
input.

### What would fix it

Nothing to fix in the sense of a corrected predicate — there is no encoding a
`GeneralName` can carry that produces the state this checks for, given how
`GENERAL_NAME_get0_value` is implemented. The function is either vestigial
(kept from a time predating typed union access, or defensive against a future
OpenSSL API change) or was written against a mistaken belief about what
`GENERAL_NAME_get0_value` returns. Removing the two dead branches would not
change any observable behaviour.

### How this lane handled it
