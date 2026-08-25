# ZT-081 — an IP address in a dNSName is reported as an invalid TLD

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl, python3 |
| **Cases** | positive/ |
| **Verified against** | corpus certificate |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```
$ zlint positive/ZT-081-ip-address-in-dnsname.pem     # its only SAN is DNS:213.16.25.173
error    e_dnsname_not_valid_tld              <- observed
```

**The repair the finding names cannot be made.** No TLD can be registered that
turns `213.16.25.173` into a conforming `dNSName`; the value has to move into
an `iPAddress` entry. A CA acting on this finding is told to fix the wrong
thing.

**And no lint reports the real defect.** zlint has 33 lints whose names
mention a DNS name and none tests whether the value parses as an IP address.
`lint_subject_contains_malformed_arpa_ip` and
`lint_subject_contains_reserved_arpa_ip` do parse IPs, but both are about
`.arpa` names rather than an IP literal in a `dNSName`.

Low because the verdict does not change: an IP address in a `dNSName` is
non-conforming and zlint condemns it. What is wrong is the requirement named.

Fix: skip a value `net.ParseIP` accepts in `DNSNameValidTLD.Execute`, and add
a lint for the real defect citing BR § 7.1.2.7.12.
