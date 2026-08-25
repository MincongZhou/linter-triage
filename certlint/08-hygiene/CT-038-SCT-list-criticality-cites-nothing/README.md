# CT-038 — SCT list criticality cites nothing

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `08-hygiene` — Descriptions, citations, severities and tests |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

### The code

`lib/certlint/extensions/signedcertificatetimestamplist.rb:20-25`:

```ruby
def self.lint(content, cert, critical = false)
  messages = []
  if critical
    messages << 'E: SignedCertificateTimestampList must not be critical'
  end
  messages
end
```

No comment, no citation, and the file's only content is this check plus the
`register_handler` call.

### What the citation actually states

RFC 6962 § 3.3 defines the embedded SCT list extension (OID
`1.3.6.1.4.1.11129.2.4.2`) and never states a criticality requirement for it —
the document's only explicit criticality statement is about the *poison*
extension (§ / precertificate construction: "a special critical poison
extension... this extension is to ensure that the Precertificate cannot be
validated by a standard X.509v3 client"), a different OID entirely. RFC 9162,
the SCT scheme's later standardization, states "SHOULD be noncritical" for its
own *Transparency Information* extension (OID `1.3.101.75`) — again a
different OID, the v2 replacement rather than the v1 extension this check
reads. Neither document that defines `1.3.6.1.4.1.11129.2.4.2` states this
check's requirement in words.

### Observed and correct

Grepped both `Specs/rfc/rfc6962.txt` and `Specs/rfc/rfc9162.txt` for
"critical" (case-insensitive): three occurrences total, all about the poison
extension or the unrelated v2 OID, none about the v1 SCT list extension's own
criticality. `observed`: an unconditional "E:". `correct`: no MUST or SHOULD
in either governing document names this population, so an error-level, undated
finding overstates what either RFC actually commits to — even though marking
the extension critical would in practice make the certificate unusable to any
client that has not implemented SCT parsing, which is presumably *why* every
real embedded-SCT certificate marks it non-critical.

### What would fix it

Either find the actual source of this convention (a CT policy document, a root
program requirement) and cite it, or drop the check as advisory practice
rather than a specification requirement.

### How this lane handled it

Not ported. This is a `defect` verdict against
`lib/certlint/extensions/signedcertificatetimestamplist.rb::E:
SignedCertificateTimestampList must not be critical::1` — the sole site in
that file — rather than an invented citation.
