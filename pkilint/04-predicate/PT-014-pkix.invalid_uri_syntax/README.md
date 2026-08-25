# PT-014 — a URI syntax check delegated to a library stricter than RFC 3986

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | mechanism read from `pkilint/pkix/general_name.py` and Python `validators` |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

`pkix.invalid_uri_syntax` is registered on every `GeneralName` bearing a
`uniformResourceIdentifier` and cites RFC 5280 §4.2.1.6, which requires the
value to be "a URI as defined in [RFC 3986]". The check does not implement RFC
3986; it delegates to Python's `validators.url`, which is a *usability*
validator for web addresses and is stricter than the grammar in three ways
that matter here. Each one reports a conforming certificate as defective:

**A fixed scheme allow-list.** RFC 3986 §3.1 admits any `ALPHA *( ALPHA /
DIGIT / "+" / "-" / "." )`, and RFC 5280 places no scheme restriction on a SAN
URI at all. `validators.url` accepts a closed set, so `test://…` and `sip:…`
are reported — on three of pkilint's own comparison fixtures
(`SANURIHostFQDN.pem`, `SANURIHostWildcardFQDN.pem`, `SANURINoAuthority.pem`).

**Unregistered schemes.** One certificate carries scheme `hhttp` — plainly a
typo, and plainly a *syntactically legal* scheme token. RFC 5280 does not
require a registered scheme, so this is a finding about plausibility rather
than about conformance.

**A query-string regex that rejects a leading hyphen.** Two telesec CRL
distribution points carry `?-crl_format=X_509&…`. Hyphen is in RFC 3986's
`unreserved` set and is legal at any position in a query.

**Observed** six certificates reported as invalid URI syntax. **Correct** none
of the six: all are conforming under RFC 3986.

**One line**: implement the RFC 3986 grammar, or narrow the citation to say
what the check actually enforces.

### The same check declines a case that is a real violation

Not part of the defect, and worth recording beside it because the two together
describe the check's real shape. That is legal as LDAP DN text under RFC 4514
and illegal once placed in a URI: RFC 4516 §2 and RFC 3986 §2.2 both require
percent-encoding. Every sample checked is real major-CA issuance already tied
to a compliance incident.

So pkilint over-reports six conforming URIs and declines seventy defective
ones, through the same validator.
