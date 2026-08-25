# ZT-093 — `w_etsi_natural_person_key_usage_preferred_values` double-reports every invalid `keyUsage` alongside its own sibling

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `08-hygiene` — Descriptions, citations, severities and tests |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | fabricated certificate, recipe below |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

zlint carries three lints reading EN 319 412-2 clause 4.3.2, one sentence
long:

> The key usage extension shall be present and shall contain one (and only
> one) of the key usage settings defined in table 1 (A, B, C, D, E or F).
> Type A, C or E should be used to avoid mixed usage of keys.

`e_etsi_natural_person_key_usage_mandatory` reads presence,
`e_etsi_natural_person_key_usage_correct_values` reads validity (is the
setting one of the six), and
`w_etsi_natural_person_key_usage_preferred_values` reads preference (is it one
of the three single-purpose ones). The third lint's own `Execute` tests
`c.KeyUsage` against the four preferred bit patterns directly:

```go
func (l *qcNaturalPersonKUPreferredSetting) Execute(c *x509.Certificate) *lint.LintResult {
	if c.KeyUsage == x509.KeyUsageContentCommitment { return &lint.LintResult{Status: lint.Pass} }  // A
	if c.KeyUsage == x509.KeyUsageDigitalSignature   { return &lint.LintResult{Status: lint.Pass} }  // C
	if c.KeyUsage == x509.KeyUsageKeyEncipherment    { return &lint.LintResult{Status: lint.Pass} }  // E
	if c.KeyUsage == x509.KeyUsageKeyAgreement       { return &lint.LintResult{Status: lint.Pass} }  // E
	return &lint.LintResult{Status: lint.Warn, ...}
}
```

Anything that is not one of those four patterns draws the warning — including
a `keyUsage` that is not a valid row of table 1 at all, which
`e_etsi_natural_person_key_usage_correct_values` already tests, separately,
against all seven combinations (six settings, E counted twice), reporting an
error on everything outside them. The "preferred" check never asks whether the
certificate passed the "valid" check first.

**Reproduction.** A natural-person certificate (QCP-n, `0.4.0.194112.1.0`)
whose `keyUsage` asserts `digitalSignature` and `keyCertSign` — a setting
outside every row of table 1, chosen because `keyCertSign` names no column of
it at all:

```
$ zlint -includeNames=e_etsi_natural_person_key_usage_correct_values,w_etsi_natural_person_key_usage_preferred_values invalid-ku.pem
{"e_etsi_natural_person_key_usage_correct_values":{"result":"error","details":"KeyUsage [DigitalSignature CertSign] (00100001) is not allowed for ETSI natural person certificates"},
 "w_etsi_natural_person_key_usage_preferred_values":{"result":"warn","details":"KeyUsage (00100001) should not be used for ETSI natural person certificates"}}
```

Both lints fire on the same certificate. Executed, not just read from source —
`zlint -version` on this machine prints `dev-unknown` rather than the pinned
`v3.7.1-20-g1007b1d5`, so this is evidence the *current* checked-out source
behaves this way, not a confirmed reproduction against the exact pin; see
"What was not verified".

**observed**: an invalid `keyUsage` draws an error from
`e_etsi_natural_person_key_usage_correct_values` **and** a warning from
`w_etsi_natural_person_key_usage_preferred_values`, naming a preference among
settings the certificate never chose one of. **correct**: the clause's third
sentence is a preference *among the six permitted settings*, so a `keyUsage`
that fails the second sentence (is not one of the six) has nothing for the
third sentence to prefer among. One obligation — choose a valid setting — is
answered twice, under two identifiers, at two severities.

**mechanism**: the "preferred" lint's `CheckApplies` is `IsEtsiQcNaturalPerson
&& HasKeyUsageOID && IsSubscriberCert` — the same gate as its "correct values"
sibling, with no cross-check between the two.

### Corrected by the integrator, 2026-08-23: the reach is not zero, and it is
### one of zlint's own fixtures

So the double-report is not a fabricated case at all: it occurs on zlint's own
test data, which the gap-reporting skill names as the strongest report
available.

## What was not verified

The Go source read for both findings above is the checked-out
`pkimetal-linters/zlint` tree, and ZL-T02's reproduction ran against whatever
binary `~/.local/bin/zlint` on this machine actually is — not confirmed to be
a build of the pinned commit, only assumed to be, since rebuilding and diffing
(the check the reproduction beside this file's own header describes) was
outside this lane's scope. A source read plus one executed reproduction is the
evidence on offer; a pin re-verification is not. - ZL-T01 (the AIA citation)
was investigated entirely from the document archive and the lint's source; the
check was not executed against a built certificate. The claim is about missing
textual grounding for a citation, which running the check would not settle
either way — but a reader wanting to see the check's actual runtime output on
an internal-name AIA has not gotten it here. - Neither finding was checked
against the reproduction beside this file beyond a keyword grep for the two
identifier names; a prior investigation using different wording would not have
been caught.

## Two further findings at the `w_smime_aia_contains_internal_names` site

Found by the integrator while verifying ZT-092. Both are about the same lint
the lane examined, and neither is about its citation.

### The lint is `w_`-prefixed and returns `lint.Error` on two paths

```go
for _, u := range c.OCSPServer {
    purl, err := url.Parse(u)
    if err != nil {
        return &lint.LintResult{Status: lint.Error}
    }
```

— and again identically for `c.IssuingCertificateURL`. zlint's own contributor
guide states the rule this breaks: *"Lints only return one non-success or
non-fatal status, which must also match their name prefix."* A certificate
whose AIA carries a URI Go's `url.Parse` rejects is therefore reported as an
**error** under a warning-prefixed identifier, and a consumer selecting lints
by severity gets a result its own name denies it can produce.

The same shape appears in `cabf_br`'s
`lint_sub_cert_aia_contains_internal_names.go`, from which this lint is
plainly derived, so a fix should address both.

This is the same class as the three CRL lints already recorded in the
reproduction beside this file for emitting two severities under one name, and
should be merged into whatever entry covers those rather than numbered
separately if the integrator judges them one defect.

### `HasValidTLD(purl.Hostname, time.Now)` — the calendar, not the certificate

**Not yet a defect claim; an open question, deliberately unnumbered.**

`util.HasValidTLD` takes a time parameter because zlint's `util/gtld_map.go`
carries each TLD's delegation *and removal* date, which is what makes a TLD
check historically accurate. Three call sites pass the certificate's own date:

```
lints/cabf_br/lint_dnsname_right_label_valid_tld.go:48   c.NotBefore
lints/cabf_br/lint_dnsname_right_label_valid_tld.go:53   c.NotBefore
```

Two lints pass `time.Now` instead — this one and the `cabf_br` sibling it was
copied from. The consequence is that the same certificate lints differently on
different days: a name under a TLD delegated after issuance stops being
reported, and one under a TLD since removed from the root zone starts being.

Two of anything is a design rather than a slip, and there is a defensible
reading here — an AIA URI has to resolve *now*, not at issuance, so "is this
host under a live TLD today" may be the intended question. Against that:
`HasValidTLD` answers root-zone delegation, not resolvability, and a
non-reproducible warning is a poor way to ask about liveness.

**Settle the reading before reporting this upstream.** Recorded here so the
next lane touching either AIA lint does not re-derive it, and marked
unnumbered per the numbering rule — a number asserts a defect exists, and this
one is not yet established.
