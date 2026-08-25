# XT-004 — `ERR_INVALID_GENERAL_NAME_TYPE` is unreachable for the same reason, one level up

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

`checks.c:1048`–`1054`, inside `CheckSAN`'s per-entry loop, immediately after
`GENERAL_NAMES *names = X509_get_ext_d2i(...)` has already succeeded:

```c
for (int i = 0; i < sk_GENERAL_NAME_num(names); i++)
{
	GENERAL_NAME *name = sk_GENERAL_NAME_value(names, i);
	int type;
	ASN1_STRING *name_s = GENERAL_NAME_get0_value(name, &type);
	if (type > GEN_RID || type < 0)
	{
		SetError(ERR_INVALID_GENERAL_NAME_TYPE);
	}
	...
```

`GEN_RID` is 8, the highest of OpenSSL's nine `GEN_*` constants
(`GEN_OTHERNAME` 0 through `GEN_RID` 8), one per `GeneralName` `CHOICE`
alternative. The claim is that an entry inside a successfully-decoded
`GeneralNames` list could carry a `type` outside that range.

### Why the claim is false, and how that was settled

`GENERAL_NAME`'s `->type` is set by which `CHOICE` alternative the decoder
matched — it can only be one of the nine tags the `CHOICE` declares. The
question is what happens to an *out-of-range* tag on the wire, and that is a
decode-level question settled by executing the decoder, not by reading the
loop. `XL-T-x5-h-02-gen-name-range.c` builds a `GeneralNames` SEQUENCE
containing one entry tagged `[9]` (0x89), one past `GEN_RID`, both alone and
alongside a valid `[2]` `dNSName` entry, and runs each through
`d2i_GENERAL_NAMES`:

```
Case: GeneralName tag [9] (out of range)
  d2i_GENERAL_NAMES: FAILED TO PARSE (whole SEQUENCE rejected)
Case: GeneralName tag [15]
  d2i_GENERAL_NAMES: FAILED TO PARSE (whole SEQUENCE rejected)
Case: mixed valid dNSName + out-of-range [9]
  d2i_GENERAL_NAMES: FAILED TO PARSE (whole SEQUENCE rejected)
```

An out-of-range tag anywhere in the `SEQUENCE` fails the whole decode —
`d2i_GENERAL_NAMES` returns `NULL`, not a partial list with an unrecognised
entry. In `CheckSAN` that takes the `names == NULL` branch two lines above
(`checks.c:1024`), which raises `ERR_INVALID` — `checks.c::ERR_INVALID::2`, a
different site in this same lane — and the per-entry loop this check lives in
is never reached at all for that certificate. Every entry the loop does see
has already been decoded successfully, which per the mechanism in `XT-003`
means its `type` is one of the nine values the decoder is capable of
producing.

### Why High

Same reasoning as `XT-003`: the check can never fire, one of the three High
conditions in the gap-reporting skill's severity table. It is worth recording
as a separate entry rather than folded into `-01` because the mechanism is
different — `-01` is about a field OpenSSL's template forces regardless of
wire content, and this is about a decode failure that pre-empts the branch
entirely, one call frame up.

### What would fix it

Nothing to fix for the same reason as `-01`: there is no certificate that
reaches this branch with an out-of-range `type`. Dead code, not a wrong
predicate.

### How this lane handled it

Not ported. `checks.c::ERR_INVALID_GENERAL_NAME_TYPE::1` is recorded `defect`.
