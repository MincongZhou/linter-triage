# ZT-007 — `e_subject_dn_not_printable_characters` reads raw octets, whatever the tag

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `00-already-filed` — Already on your issue tracker |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl, python3 |
| **Cases** | positive/ |
| **Verified against** | zlint's own fixture plus a real root |
| **Would otherwise sit in** | see the adjudication below |

## Upstream issues, adjudicated

- **#818** — Printable `BMPString` in subject DN fields marked as failing lint `e_subject_dn_not_printable_characters` *(open)*
  **duplicate.** See ZT-003. Upstream files these two as one.

## Analysis

The lint runs `utf8.DecodeRune` over `attrTypeAndValue.Value.Bytes` — the
undecoded DER content octets — and faults any rune below `0x20`, without
consulting the attribute's declared ASN.1 tag. A `UniversalString` encodes
each character as four octets UCS-4BE and a `BMPString` as two UCS-2BE, so
every ASCII character carries three or one leading `0x00`. Read as UTF-8 those
are `U+0000`, which the C0 test calls a control character the decoded value
does not contain.

Demonstrated on zlint's own `subjectCNWrongEncoding.pem`, whose `commonName`
is a `UniversalString` with content `00 00 00 55` decoding to `CN=U` — one
ordinary printable character — and on the A-Trust root, whose
`organizationName` is a `BMPString` of ordinary German text. Both are
reported.

This contradicts the lint's own `Description` and its `Citation` to RFC 5280
§4.1.2.4, which govern a `DirectoryString`'s decoded content rather than its
transfer encoding. **Not a house pattern**: the sibling DN-encoding lints
(`e_subject_dn_country_not_printable_string` and the issuer and serialNumber
equivalents) test the declared *tag*, which is a differently shaped and
correct question. Fix: decode per the declared tag before scanning.
