# CT-021 — an IP address in a dNSName is reported as an unknown TLD

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | two real incident certificates |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```
$ cablint positive/CT-021-ip-address-in-dnsname.pem     # its only SAN is DNS:213.16.25.173
E: Unknown TLD in SAN
```

The value is an address, not a name whose top-level domain happens to be
unregistered. RFC 5280 § 4.2.1.6 gives `dNSName` for domain names and
`iPAddress` for addresses, and BR § 7.1.2.7.12 states the same split. The
certificate is non-conforming; "unknown top-level domain" is not what is wrong
with it, and the requirement named is what a CA reads when deciding what to
fix.

```
iananames.rb:93   unless fqdn.include? '.'  →  'E: Unqualified domain name'
iananames.rb:98   tld = fqdn.split('.').last
iananames.rb:100  if tld_type.nil?          →  'E: Unknown TLD'
```

`213.16.25.173` contains a dot, so it passes the qualification test, and its
last label is `173`, which no registry carries. Nothing in `IANANames.lint`
asks whether the value is an address, and the function is called from exactly
one place — `cablint.rb:673`, over the SAN's `dNSName` entries.

Low because no verdict changes: cablint condemns the certificate and the
certificate deserves it. The control in the reproduction earns the same
message honestly, which is what shows this is the input rather than the check.

Fix: an address test before the label lookup — an IP literal is never a domain
name, so no TLD question arises about it — and a finding of its own for the
real defect.
