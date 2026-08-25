# CT-006 — the 39-month BR ceiling is dated 15 months too early, ignoring a documented CA exception the same clause states

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | fabricated, recipe below |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

### The code

```ruby
MONTHS_39 = Time.utc(2015, 4, 2)
# ...
elsif c.not_before >= MONTHS_39
  if days > (366 + 365 + 365 + 31 + 31 + 30 + 1)
    messages << 'E: BR certificates must be 39 months in validity or less'
  end
```

### What the defining document says

CAB Forum BR v1.0.0 §9.4, effective **2012-07-01**, and every version through
**v1.4.3** (effective 2017-09-08) states the *same* clause with the same
carve-out, only the sunset date for the carve-out changing between editions:

> Except as provided for below, Subscriber Certificates issued after 1 April
> 2015 MUST have a Validity Period no greater than 39 months.
>
> Until 30 June 2016, CAs MAY continue to issue Subscriber Certificates with
> a Validity Period greater than 39 months but not greater than 60 months
> provided that the CA documents that the Certificate is for a system or
> software that: (a) was in use prior to the Effective Date; (b) is currently
> in use by either the Applicant or a substantial number of Relying Parties;
> (c) fails to operate if the Validity Period is shorter than 60 months;
> (d) does not contain known security risks to Relying Parties; and (e) is
> difficult to patch or replace without substantial economic outlay.

So the 39-month cap is genuinely unconditional only from **2016-07-01**
onward. Between 2015-04-02 and 2016-06-30, a CA could lawfully issue a
Subscriber Certificate valid for up to 60 months, provided it documented the
exception — a fact the certificate itself does not carry and cannot be read
from the DER. `cablint`'s `MONTHS_39` constant is the earlier of the two
dates, and its check carries no exception logic at all: every certificate in
that 15-month window with a Validity Period over 39 months and up to 60 months
draws `E: BR certificates must be 39 months in validity or less` regardless of
whether the CA lawfully invoked the carve-out.

### Reproduction

Fabricated with `cryptography` (2005-06-01 issuance date argument aside, this
is the actual recipe used):

```python
import datetime
from cryptography import x509
from cryptography.x509.oid import NameOID, ExtendedKeyUsageOID
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import rsa

key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
name = x509.Name([
    x509.NameAttribute(NameOID.COUNTRY_NAME, "US"),
    x509.NameAttribute(NameOID.COMMON_NAME, "example.test"),
])
nb = datetime.datetime(2015, 6, 1, tzinfo=datetime.timezone.utc)
na = nb + datetime.timedelta(days=1800)  # 59 months: over 39, within 60
cert = (
    x509.CertificateBuilder()
    .subject_name(name).issuer_name(name)
    .public_key(key.public_key())
    .serial_number(x509.random_serial_number())
    .not_valid_before(nb).not_valid_after(na)
    .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=True)
    .add_extension(x509.KeyUsage(digital_signature=True, content_commitment=False,
        key_encipherment=True, data_encipherment=False, key_agreement=False,
        key_cert_sign=False, crl_sign=False, encipher_only=False, decipher_only=False),
        critical=True)
    .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]), critical=False)
    .add_extension(x509.SubjectAlternativeName([x509.DNSName("example.test")]), critical=False)
    .sign(key, hashes.SHA256())
)
```

```
$ ruby -I lib -I ext bin/cablint CL-T-cl-d-01-synthetic-59mo-exception-window.pem
I: TLS Server certificate identified	CL-T-cl-d-01-synthetic-59mo-exception-window.pem
E: BR certificates must be 39 months in validity or less	CL-T-cl-d-01-synthetic-59mo-exception-window.pem
...
```

**correct**: no finding from this check alone — BR 1.0.0-1.4.3 §9.4/§6.3.2
permits up to 60 months in this window, conditioned on a fact (whether the CA
documented the exception) the certificate cannot express.

### Fix

Either drop the unconditional 39-month check for `notBefore` in `[2015-04-02,
2016-06-30]` and defer to the (also unimplemented) 60-month cap for that
window, or move `MONTHS_39` to `2016-07-01` to match the date the carve-out
itself expires.
