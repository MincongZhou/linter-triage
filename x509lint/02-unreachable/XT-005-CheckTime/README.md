# XT-005 — `CheckTime`'s two EV limbs are dead code: the EV flag is set 73 lines of call sequence after it is read

| | |
|---|---|
| **Tool** | `kroeckx/x509lint` at `103c92f` |
| **Group** | `02-unreachable` — Checks that cannot fire |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

### The code

`CheckTime` (`checks.c:1380`) branches on the certificate's EV status:

```c
if (type == SubscriberCertificate)
{
    if (GetBit(cert_info, CERT_INFO_EV))
    {
        /* EV 9.4 */
        if (IsValidLongerThan(*tm_before, *tm_after, 27))
            SetError(ERR_EV_LONGER_27_MONTHS);
        else if (IsValidLongerThan(*tm_before, *tm_after, 12))
            SetWarning(WARN_EV_LONGER_12_MONTHS);
    }
    else
    {
        /* CAB 9.4.1 */
        ... ERR_LONGER_60_MONTHS / WARN_LONGER_39_MONTHS
    }
}
```

`CERT_INFO_EV` is written in exactly one place, `checks.c:809`, inside
`CheckPolicy`. It is read in exactly one place, `checks.c:1403`, the line
above. And `check` calls them in this order:

```
checks.c:2160   Clear();                        /* zeroes cert_info, checks.c:194 */
checks.c:2207   CheckTime(x509, &tm_before, &tm_after, type);
...
checks.c:2280   CheckPolicy(x509, type, subject);
```

So the read always sees zero. Both EV limbs are unreachable, and every EV
subscriber certificate is measured against the general 60/39-month ceiling
instead of its own.

### What the citation states

EV Guidelines § 6.3.2 (§ 9.4 through v1.6.1, § 8(a) in v1.0.0): "The validity
period for an EV Certificate SHALL NOT exceed twenty seven months. It is
RECOMMENDED that EV Subscriber Certificates have a maximum validity period of
twelve months." One sentence, two requirements, and x509lint implements both —
it just cannot run either.

### Observed and correct, with a control that closes the alternative reading

Three fabricated certificates, all asserting `2.23.140.1.1` — the reserved EV
policy identifier and the first entry of the twelve-OID table at
`checks.c:795`.

```
40-month EV certificate    W: The certificate is valid for longer than 39 months
20-month EV certificate    (nothing about validity at all)

control: the 40-month
certificate with           E: EV certificate without business
businessCategory removed   W: The certificate is valid for longer than 39 months
```

`correct` — `E: EV certificate valid longer than 27 months` for the first, `W:
EV certificate valid longer than 12 months` for the second.

**The control is what makes this airtight.** `E: EV certificate without
business` is raised at `checks.c:818`, nine lines after the
`SetCertInfo(CERT_INFO_EV)` at 809 and inside the same `if`. Its appearance
proves x509lint recognises this certificate, on this OID, on this run, as EV.
The certificate is still measured against the general ceiling, because
`CheckTime` had already run.

### Reach

The loss is not only the missing findings. Until 2020 the general ceiling was
the *looser* of the two — 39 months against 27, and 39 months against a
12-month recommendation — so an EV certificate between 27 and 39 months draws
a warning naming the wrong number, and one between 12 and 39 months draws
nothing.

### Fix

Move the EV classification ahead of `CheckTime`, or split it out of
`CheckPolicy` into a pass that runs first. The general form is the one
`XT-006` already asks for: establish the certificate's purpose and policy
class once, before any check consults it.

### How this lane handled it

`checks.c::ERR_EV_LONGER_27_MONTHS::1` is `answered` by
`cabf_ev/e_ev_valid_time_too_long`, which implements the clause and reaches
the population x509lint's dead branch cannot.
