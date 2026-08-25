# CT-037 — EC "encipherOnly and decipherOnly both set" cites nothing

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

`lib/certlint/extensions/keyusage.rb:87-89`:

```ruby
if (v.include? 'Encipher Only') && (v.include? 'Decipher Only')
  messages << 'E: Encipher Only and Decipher Only must not both be set'
end
```

Inside the `OpenSSL::PKey::EC` branch, unconditional on role or date, no
comment.

### What the citation actually states

RFC 5280 § 4.2.1.3 defines both bits without prohibiting their joint
assertion: "The meaning of the encipherOnly bit is undefined in the absence of
the keyAgreement bit... [same for decipherOnly]" — undefined without
`keyAgreement`, not forbidden together. RFC 3279 § 2.3.5 *does* state "The
keyUsage extension MUST NOT assert both encipherOnly and decipherOnly" — but
only in the paragraph governing "a CA or CRL issuer certificate," dated
2002-04-01. RFC 5480 § 3, the document this tree treats as authoritative for
EC key usage from 2009-03-01 onward (`rfc5480/n_ecdsa_ee_invalid_ku`'s own
REASONING.md explains why), restates the CA paragraph's other content — the
`keyCertSign`/`cRLSign` RECOMMENDS — but does not restate the "MUST NOT both"
sentence at all, for either role.

So the code's claim is true only for a CA-or-CRL-issuer EC certificate issued
2002-04-01 through 2009-02-28, and even then only via a document (RFC 3279) a
later one (RFC 5480) silently superseded on this exact point. certlint applies
it to any EC certificate, any role, any date, with no citation in the source
at all.

### Observed and correct

Not a control-flow claim; settled by reading RFC 3279 § 2.3.5 and RFC 5480 § 3
side by side (excerpted above) rather than by executing anything. `observed`:
an unconditional "E:" for any EC certificate. `correct`: the requirement,
where it exists at all, is scoped to CA/CRL-issuer certificates in a five-year
window that RFC 5480 then dropped.

### How this lane handled it

Not ported. The parallel DH clause (RFC 3279 § 2.3.3) states the identical
"MUST NOT assert both" sentence with no CA-only qualifier and no superseding
document, so *that* population is real and is `e_dh_encipher_decipher_only_
both_set` (some, DH being essentially unused, but genuinely cited). The EC
site is deferred to this record rather than ported with an invented scope.
