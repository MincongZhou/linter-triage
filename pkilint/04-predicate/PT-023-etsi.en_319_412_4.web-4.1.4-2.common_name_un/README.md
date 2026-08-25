# PT-023 — the ETSI commonName check contradicts pkilint's own Forum check on one certificate

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

`en_319_412_4` builds both its commonName validators with

```python
_ALLOWED_GENERAL_NAME_TYPES = {general_name.GeneralNameTypeName.DNS_NAME}
```

while `cabf/serverauth/serverauth_subscriber.SubscriberCommonNameValidator`,
whose docstring cites BR 7.1.4.3, builds the same base class with

```python
{general_name.GeneralNameTypeName.DNS_NAME,
 general_name.GeneralNameTypeName.IP_ADDRESS}
```

QNCP-w certificate types are members of `CABF_CERTIFICATE_TYPES`, so
`etsi.create_validators` installs `QncpWCommonNameValidator` **and** delegates
to `serverauth.create_validators`, which installs the Forum one. Both run on
the same certificate and disagree.

The clause decides it. WEB-4.1.4-1 says "all certificate fields and extensions
shall comply with requirements on subscriber certificates stated in the BRG",
and BR 7.1.4.2.2 permits a commonName that is an IP address copied from an
`iPAddress` entry of the `subjectAltName`. WEB-4.1.4-2 is the sentence
pkilint's docstring quotes, and it is a **permission** — "the subject
commonName **may** contain a domain name or a Wildcard Domain Name … which is
one of the dNSName values" — not a prohibition on the other value BR 7.1.4.2.2
allows. Reading it as an exhaustive list makes WEB-4.1.4-2 override the
document WEB-4.1.4-1 incorporates.

### Reproduction

Two QNCP-w-OV certificates differing only in the name they carry:

```
$ lint_etsi_cert lint -d -o -r -s ERROR G-qncpw-ov-cn-is-ip.pem
QNCP-W-OV-EIDAS-FINAL-CERTIFICATE
    etsi.en_319_412_4.web-4.1.4-2.common_name_unknown_source (ERROR):
        Unknown source for value of common name: "93.184.215.14"
$ lint_etsi_cert lint -d -o -r -s ERROR H-qncpw-ov-cn-is-dns.pem
QNCP-W-OV-EIDAS-FINAL-CERTIFICATE
    (no finding)
```

Both carry `2.23.140.1.2.2` and `0.4.0.194112.1.5`, `serverAuth`/`clientAuth`,
and a `qcStatements` with `QcCompliance` and `QcType` `id-etsi-qct-web`. The
first has commonName `93.184.215.14` and `subjectAltName` `iPAddress
93.184.215.14`; the second has commonName `www.example.com` and
`subjectAltName` `dNSName www.example.com`. A routable address rather than one
of the IETF documentation ranges, so `cabf.internal_ip_address` does not fire
beside the finding and confuse the report.

**observed** — an ERROR on the first, from the ETSI code, while
`cabf.serverauth.subscriber_common_name_unknown_source` stays silent on the
same certificate. **correct** — silence from both: the value is one BR
7.1.4.2.2 permits, and WEB-4.1.4-1 imports that clause.

### Fix

Give the two `en_319_412_4` validators the same allowed set as the serverauth
one. The ETSI-specific set adds nothing: for the NCP-w types WEB-4.1.3-4 c)
imports BR 7.1.4.2.2 in the same way.

### Severity
