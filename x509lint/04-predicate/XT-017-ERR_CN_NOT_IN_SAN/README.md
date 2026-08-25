# XT-017 — `ERR_CN_NOT_IN_SAN` has been commented out since 2016

| | |
|---|---|
| **Tool** | `kroeckx/x509lint` at `103c92f` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | `pkimetal-linters/x509lint` commit `5135ee7b`, still absent at the pinned commit `103c92f2f` |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

### The code

`checks.c:1152`–`1155`, the last statement of `CheckSAN`:

```c
if (commonName != NULL && bSanFound && !bCommonNameFound)
{
//		SetError(ERR_CN_NOT_IN_SAN);
}
```

The `SetError` call is a comment. `messages.c:85` still carries the message
text (`"E: commonName not in subjectAltName extension\n"`) and `checks.h:67`
still defines the constant, but nothing in the vendored tree calls it — this
is the finding's only appearance in `checks.c`, confirmed with `grep -rn
ERR_CN_NOT_IN_SAN.` across the whole vendored directory.

### The history

`git log -p -S 'SetError(ERR_CN_NOT_IN_SAN)' -- checks.c` in the vendored
tree's own history:

```
commit 4157c9e1  2016-03-26  "Check that commonName is present in SAN."
    (adds the SetError call)
commit 5135ee7b  2016-04-14  "Disable error for now"
    "It gives an error for cases it shouldn't."
    (comments the call out)
```

Nineteen days from introduction to disablement, and it has stayed disabled for every commit since — including `103c92f2f`, this lane's pinned commit, dated 2026-01-09, a decade later. `git log --oneline -- checks.c | wc -l` counts 170 commits to this file since; none re-enables it.

### The requirement is real and current

The upstream author's own commit message says the check had false positives,
not that the requirement stopped existing. BR § 7.1.4.3, *Subscriber
Certificate Common Name Attribute*, is current text: "If present, this
attribute MUST contain exactly one entry that is one of the values contained
in the Certificate's `subjectAltName` extension," with the 2021-08-25 rewrite
tightening "one of the values" to "a character-for-character copy." A
`commonName` that names a host absent from `subjectAltName` violates a live
MUST.

### How this lane handled it

- `cabf_br/e_subject_common_name_not_from_san` (2012-07-01 to 2021-08-24, case-insensitive comparison — the text in force for that era) - `cabf_br/e_subject_common_name_not_exactly_from_san` (2021-08-25 on, exact comparison)

Both exclude delegated OCSP responders, which BR § 7.1.2.8.2 forbids from
carrying a `subjectAltName` at all — a certificate the requirement cannot
apply to rather than one that happens to conform. Recorded `answered` for
`checks.c::ERR_CN_NOT_IN_SAN::1` in `ledger-fragment.json`, citing both
identifiers; the ledger note also flags that x509lint's own version of this
check has never fired on anything, so there is no upstream behaviour to
diverge from — only an upstream absence to not mistake for "no requirement."
