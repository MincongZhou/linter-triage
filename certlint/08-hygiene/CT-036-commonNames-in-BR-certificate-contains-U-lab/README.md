# CT-036 — `commonNames in BR certificate contains U-labels` is a Warning where BR § 7.1.4.3 states a MUST

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `08-hygiene` — Descriptions, citations, severities and tests |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | one of zlint's own fixtures, used as certlint's input, plus a control from the corpus |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

### The code

```ruby
# To check that the CN matches a SAN entry, first check for case insensitive direct match
# Then check for case sensitive match in UTF-8 encoded IDNs
# RFC 5891 section 3.1.2 makes this clear:
#  A pair of A-labels MUST be compared as case-insensitive ASCII (as with
#  all comparisons of ASCII DNS labels).  U-labels MUST be compared
#  as-is, without case folding or other intermediate steps.
subjectarr.select { |rdn| rdn[0] == 'CN' }.each do |rdn|
  val = rdn[1]
  unless names.include? val.downcase
    if idn_san.include? val
      messages << 'W: commonNames in BR certificate contains U-labels'
    else
      messages << 'E: commonNames in BR certificates must be from SAN entries'
    end
  end
end
```

`idn_san` (built just above, lines 715-721) is the list of `subjectAltName`
`dNSName` entries that carry `xn--` decoded back to Unicode with
`SimpleIDN.to_unicode`. So this branch fires precisely when the subject's
`commonName` is the **Unicode rendering** of an A-label (`xn--...`) `dNSName`
that is genuinely present in the SAN — and reports it as a mere Warning
instead of the `E:` the sibling branch two lines below gives every other
CN/SAN mismatch.

### What the cited clause actually says

CAB Forum BR § 7.1.4.3, `Policies/Cert-BR-Baseline.md:1862` (current text):

> If the value is a Fully-Qualified Domain Name or Wildcard Domain Name, then
> the value MUST be encoded as a character-for-character copy of the
> `dNSName` entry value from the `subjectAltName` extension. Specifically, all
> Domain Labels of the Fully-Qualified Domain Name or FQDN portion of the
> Wildcard Domain Name must be encoded as LDH Labels, and **P-Labels MUST NOT
> be converted to their Unicode representation.**

This is not ambiguous about the case this branch handles: rendering a P-Label
(`xn--...`) as Unicode in the `commonName` is exactly, by name, what the
clause forbids at MUST strength. The pre-2021 text (BR 1.1.0 § 9.2.2,
`Policies/historical/br/br-1.1.0.txt:660-664`) is not weaker on this point
either — it requires the `commonName` to be "one of the values contained in
the Certificate's `subjectAltName` extension", and a Unicode rendering of an
A-label SAN value is not that value under either a byte or a case-insensitive
comparison, so no historical text this lane could find licenses the downgrade.

The code comment's own citation, RFC 5891 § 3.1.2, is about how to compare two
*already-chosen* label forms to each other (A-label to A-label
case-insensitively, U-label to U-label as-is) — it says nothing about whether
presenting a `commonName` as a U-label is *itself* permitted when the BR text
says the opposite. The comment is accurate about RFC 5891 and answers a
different question than the one the severity choice needs answered.

### Reproduction

```
$ cablint 
```

```
I: TLS Server certificate identified
W: commonNames in BR certificate contains U-labels
```

`subject: CN=адвокатская-контора.москва`, SAN carries
`DNS:xn----7sbaabin3cbc7afgb4aiqh6v.xn--80adxhks` (and a `www.` sibling) —
issued 2016-08-26, so the pre-2021 text governs and the `commonName` is not
byte-identical, case-insensitively or otherwise, to either SAN value.

**Control**, same code path, same certificate population, escalating to `E:`
when the CN/SAN mismatch is *not* routed through the `idn_san` branch:

```
$ cablint 
```

```
E: BR certificates must have subject alternative names extension
E: commonNames in BR certificates must be from SAN entries
```

### How this relates to CT-039

the reproduction beside this file's `CT-039` is the neighbouring finding at
this same site: a `commonName` differing from its `dNSName` only in **ASCII
case** passes the line-731 membership check silently and produces no message
at all, missing the post-2021 exact-copy requirement entirely. CT-039 is "no
message where the newer text needs one"; this is "a message, but not the one
the text requires." Both point at the same under-specified boundary between
the 2012 membership clause and the 2021 encoding clause, from opposite sides
of it.

### What would fix it

Drop the `idn_san` special case, or downgrade it only for certificates issued
before BR 1.8.0 (2021-08-25) and treat it as the ordinary `E:` on or after —
matching the two-era split `CT-039` proposes for the sibling gap at this same
site.

### What was not verified

Whether any BR version between 1.1.0 and the 2021 rewrite ever added explicit
IDN accommodation language to § 7.1.4.3 (or its earlier § 9.2.2 numbering)
that was later removed — this lane checked the earliest (1.1.0) and current
text only, not every version in between. If such an accommodation existed for
some window, the certificates issued in that window would need excluding from
the 11, and the fix above would need a second date boundary.
