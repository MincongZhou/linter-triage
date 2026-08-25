# XT-021 — `WARN_NO_EKU` reports a real MUST as an unconditional warning

| | |
|---|---|
| **Tool** | `kroeckx/x509lint` at `103c92f` |
| **Group** | `05-spec-reading` — Differing analysis of the normative text |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

### The code

`checks.c:1561`, inside `CheckEKU`'s first-iteration, extension-absent branch:

```c
if (first)
{
    SetCertInfo(CERT_INFO_NO_EKU);
    if (type == SubscriberCertificate)
    {
        SetWarning(WARN_NO_EKU);
    }
}
```

Warning severity, unconditional on issuance date, whenever a subscriber
certificate carries no `extendedKeyUsage` extension at all.

### What the citation actually states

x509lint's own message text is `"W: Subscriber certificate without Extended
Key Usage"`, but the source carries no comment naming a document.

### What would fix it

Raise `WARN_NO_EKU` to error severity for a subscriber certificate issued on
or after BR 2012-07-01, keeping the warning (or dropping the finding entirely)
before that date, since the MUST postdates the extension's existence in any
governing document.

### How this lane handled it

Not ported — the ground is already `e_sub_cert_eku_missing`. Recorded as
`answered` in `ledger-fragment.json` for `checks.c::WARN_NO_EKU::1`, with the
severity divergence noted there and here rather than silently upgraded on
x509lint's behalf.
