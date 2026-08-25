# CT-027 — EV identification never reads the disclosed CA-specific policy arcs, only the reserved one

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | reproduced against six real bugzilla incident certificates and five of zlint's own EV fixtures, including one literally named `evNoSN.pem` ("EV, No Serial Number") that cablint runs and says nothing about |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

### The code

```ruby
certpolicies = c.extensions.find { |ex| ex.oid == 'certificatePolicies' }
unless certpolicies.nil?
  if certpolicies.value.include?('2.23.140.1.') # CABForum certificate policy present?
    if certpolicies.value.include?('2.23.140.1.1') || certpolicies.value.include?('2.23.140.1.3') # EV TLS or EV Code Signing.
      is_ev = true
    end
  elsif subjattrs.include?('1.3.6.1.4.1.311.60.2.1.3') || subjattrs.include?('jurisdictionC')
    is_ev = true
  end
end
```

`lib/certlint/cablint.rb:357-364`, immediately before the block this lane's
site 1 (`I: EV certificate identified`) reports from.

### What the EV Guidelines actually require, and why this predicate misses most of it

The EV Guidelines have never required the CABF's *reserved* policy identifier
`2.23.140.1.1`. Before Baseline Requirements 2.0.0 (2023-04-11, ballot
SC-062), an EV CA disclosed and used its **own** OID — Entrust's
`2.16.840.1.114028.10.1.2`, QuoVadis's `1.3.6.1.4.1.8024.0.2.100.1.2`,
GoDaddy's `2.16.840.1.114413.1.7.23.3`, e-Tugra's `2.16.792.3.0.4.1.1.4`, and
dozens more — every one of them a real, disclosed, EV-committing policy OID,
none of them under `2.23.140.1.`.

The code above has exactly two paths into `is_ev = true`:

1. `certificatePolicies` is present **and** contains the reserved arc. 2.
`certificatePolicies` is **absent**, and the subject happens to carry a
`jurisdictionCountryName` attribute.

A certificate asserting a disclosed CA-specific EV arc takes neither path: its
`certificatePolicies` extension is present (so path 2 never runs), and its
value does not contain `2.23.140.1.` (so path 1's outer `if` is false before
the reserved-OID check is ever reached). The certificate is classified a plain
TLS server certificate and none of the EV Guidelines checks — subject
attribute presence, the closed subject-attribute list, EV validity-period
rules — ever run on it.

### Reproduced against zlint's own fixtures

```
$ cablint evNoSN.pem              # zlint's EV-with-missing-serialNumber case
I: Certificate Transparency Precertificate identified
I: TLS Server certificate identified
E: commonNames in BR certificates must be from SAN entries
```

No `I: EV certificate identified`, no serialNumber finding — the fixture's own
purpose is silently defeated. `certificatePolicies` carries
`1.3.6.1.4.1.8024.0.2.100.1.2` (QuoVadis's EV arc). `evAllGood.pem`,
`evSubscriberNotWildCard.pem` and the `onionSANEV*` family fail the same way,
each on a different CA's disclosed arc.

### Reproduced against real issuance

```
$ cablint bug1561013-crtsh1599692465.der   # Entrust, policy 2.16.840.1.114028.10.1.2
W: Extension should be critical for KeyUsage
I: TLS Server certificate identified
```

Subject is `C=CA, ST=Ontario, L=Ottawa, O=Entrust Inc,
CN=expiredev.entrust.net` — no `jurisdictionCountryName`, no
`businessCategory`, no `serialNumber`. Every EV Guidelines subject requirement
this certificate fails to meet goes unreported. Five siblings from the same
bug (`bug1561013`) and one from `bug1398259` (SECOM, policy
`1.2.392.200091.100.721.1`, an EV OCSP responder missing `serialNumber`,
`businessCategory` and `jurisdictionCountryName`) reproduce the same way.

### What was not verified
