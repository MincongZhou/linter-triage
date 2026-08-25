# CT-019 — the self-signed-CA guard reaches two AIA branches of three

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | CCADB trust-store roots |

## Upstream issues, adjudicated

- **#25** — Adding  authorityInformationAccess extension for intermediate certificates *(closed)*
  **follow-up.** 'Adding authorityInformationAccess extension for intermediate certificates', closed, opened in response to Bugzilla 1963456 where a caIssuers URL used https instead of http. This entry is about which AIA branches the self-signed-CA guard reaches.
- **#20** — Treat OCSP URL as optional (SC063) *(closed)*
  **related.** SC063 made the OCSP URL optional; adjacent AIA reasoning, different claim.

## Analysis

```
$ cablint positive/CT-019-selfsigned-root-aia-no-ocsp.pem     # webCARES Root CA 2018
I: Self-signed CA certificate identified
N: CA certificates without Digital Signature do not allow direct signing of OCSP responses
E: CA certificates must include an HTTP URL of the OCSP responder
```

The error is BR § 7.1.2.2.c, which is the **Subordinate CA Certificate**
profile. § 7.1.2.1, the Root CA Certificate profile, states four items —
`basicConstraints`, `keyUsage`, `certificatePolicies`, `extendedKeyUsage` —
and no `authorityInformationAccess` clause at all. A root is outside the
requirement rather than exempt from it, and cablint names the certificate a
self-signed CA in the line above the error.

**cablint already has the value and already uses it twice.** The CA block
computes `is_self_signed_ca` before it says anything (`cablint.rb:156`, `is_ca
&& c.verify(c.public_key)` — a signature check, not a DN comparison) and
branches on it at 223–224 to choose which "identified" line to print. Three
branches then judge the two extensions that name URLs:

```
cablint.rb:270   ca_crldp.nil?        if !is_self_signed_ca    guarded
cablint.rb:296   ca_aia.nil?          if !is_self_signed_ca    guarded
cablint.rb:327   unless ca_has_ocsp                            not guarded
cablint.rb:334   unless ca_has_caissuers                       not guarded
```

Two of anything is a design and one is a slip; here two carry the guard and
the two immediately after it do not. Nothing distinguishes those cases, and
the value they need is in scope.

**What decides the verdict is whether the extension is present at all.** A
self-signed root with no AIA is silent, because 296 guards it. A self-signed
root carrying an AIA that names only `caIssuers` — more information, not less
— is an error. Under § 7.1.2.1 the extension is equally outside the profile
either way, so the tool is reading a distinction the document does not draw.

or after 2012-07-01, **666 carry no AIA and draw nothing here; 2 carry an AIA
without an OCSP entry and are reported** — `webCARES Root CA 2018`
(2018-04-19) and `Autoridad Raiz GSE` (2020-01-15). A third self-signed root
is reported and predates the Baseline Requirements, so it belongs to
[CT-003](#cl-004).

Fix: `unless ca_has_ocsp || is_self_signed_ca` at 327, and the same at 334.
