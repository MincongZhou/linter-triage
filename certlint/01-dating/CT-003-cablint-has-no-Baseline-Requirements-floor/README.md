# CT-003 — cablint has no Baseline Requirements floor

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ |
| **Verified against** | CCADB trust-store root |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```
$ cablint positive/CT-003-pre-br-root.pem       # a Mozilla-trusted root, notBefore 2001-01-10
E: basicConstraints must be critical in CA certificates
E: CA certificates must set keyUsage extension as critical
E: DistributionPoints other than URIs are not permitted
```

Three errors against a certificate signed eleven years and five months before
the Baseline Requirements took effect. The other two are Baseline Requirements
text: § 7.1.2.10.7 for keyUsage criticality, where RFC 5280 § 4.2.1.3 makes it
a **SHOULD** (and cablint separately emits exactly that warning on the same
run), and § 7.1.2.11.2 for the distribution point.

`cablint.rb:77`, `def self.lint(der)`, has no `not_before` test. It returns
early only on a fatal parse error or an OpenSSL exception. Nothing declines to
apply the Requirements to a certificate issued before they existed.

**The constant is present, correct, and used once.** `BR_1_0_EFFECTIVE =
Time.utc(2012, 7, 1)` at line 25; line 504 is its only reader, the last rung
of the validity-period ladder. cablint gates elsewhere on `NO_SHA1`,
`BR_1_7_1_EFFECTIVE`, `BR_2_0_0_EFFECTIVE`, `SHORTLIVED_7` and
`SHORTLIVED_10`, so this is a missing floor and not a missing capability.

```
578  CA certificates must include an HTTP URL of the OCSP responder
477  CA certificates must set keyUsage extension as critical
176  CRL Distribution Point must be an HTTP URL
121  RSA subject key modulus must be at least 2048 bits
101  CA certificates must include countryName in subject
 74  basicConstraints must be critical in CA certificates
```

**Why it matters at CT scale.** Root and intermediate certificates are
routinely fifteen to twenty years old, and a monitor running cablint over
Certificate Transparency will report roughly half of that historical
population as misissuance, burying the findings that are real.

Fix: an early return in `self.lint` when `c.not_before < BR_1_0_EFFECTIVE`.

`CT-002` is the same class one era later — BR 2.0's CDP scheme rule applied to
pre-2.0 certificates — and observes there that cablint "already implements the
pre-2.0 reading; only the gate between them is missing". This is the floor
under all of it.
