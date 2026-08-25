# XT-001 — `ERR_SAN_TYPE`'s name-type table is never scoped by certificate type, so it fires on CA certificates a subscriber-only clause does not govern

| | |
|---|---|
| **Tool** | `kroeckx/x509lint` at `103c92f` |
| **Group** | `00-already-filed` — Already on your issue tracker |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | the pinned source, read |
| **Would otherwise sit in** | see the adjudication below |

## Upstream issues, adjudicated

- **#28** — False positive: dNSName type in SAN entry of clientAuth certs *(closed)*
  **duplicate.** 'False positive: dNSName type in SAN entry of clientAuth certs', closed 2018 with no fix in the pinned tree. The same defect: the SAN name-type table is never scoped by certificate type. Worth re-opening.
- **#16** — Behaviour when EKU extension omitted *(closed)*
  **related.** 'Behaviour when EKU extension omitted', closed. Same table, the absent-EKU case.

## Analysis

### The code

`checks.c:961`–`997`, the head of `CheckSAN`, builds `name_type_allowed[]`
purely from `cert_info` bits the EKU classification set:

```c
static void CheckSAN(X509 *x509, CertType type)
{
	...
	enum { SAN_TYPE_NOT_ALLOWED, SAN_TYPE_ALLOWED, SAN_TYPE_WARN } name_type_allowed[GEN_RID+1];
	for (int i = 0; i < GEN_RID+1; i++)
	{
		name_type_allowed[i] = SAN_TYPE_NOT_ALLOWED;
	}
	if (GetBit(cert_info, CERT_INFO_SERV_AUTH) || GetBit(cert_info, CERT_INFO_ANY_EKU) || GetBit(cert_info, CERT_INFO_NO_EKU))
	{
		name_type_allowed[GEN_DNS] = SAN_TYPE_ALLOWED;
		name_type_allowed[GEN_IPADD] = SAN_TYPE_ALLOWED;
		...
```

`type` — the `CertType` parameter naming leaf, intermediate CA or root CA — is
never read anywhere in this construction. The function is called
unconditionally for every certificate, `checks.c:2281`:

```c
CheckKU(x509, type);
CheckEKU(x509, type);
CheckPolicy(x509, type, subject);
CheckSAN(x509, type);          /* no guard on type here or inside */
CheckBasicConstraints(x509, type);
```

A certificate with no `extendedKeyUsage` extension at all — the common case
for an intermediate CA — sets `CERT_INFO_NO_EKU`, which permits `dNSName`,
`iPAddress` and `rfc822Name` but nothing else: `directoryName`, `otherName`,
`x400Address`, `ediPartyName`, `registeredID` and (absent an unrecognised EKU)
`uniformResourceIdentifier` are `SAN_TYPE_NOT_ALLOWED` regardless of what kind
of certificate this is.

### Observed and correct

```
$ openssl x509 -in  \
      -inform der -noout -ext subjectAltName,basicConstraints,extendedKeyUsage,keyUsage
X509v3 Basic Constraints: critical
    CA:TRUE, pathlen:0
X509v3 Key Usage: critical
    Certificate Sign, CRL Sign
X509v3 Subject Alternative Name:
    DirName:/CN=VeriSignMPKI-2-14
```

`observed` — a `CA:TRUE` intermediate carrying no `extendedKeyUsage` and a
`directoryName` `subjectAltName` entry draws `ERR_SAN_TYPE`. `correct` — this
certificate is not a subscriber certificate, § 7.1.2.7.12 does not bind it,
and no clause in the subordinate CA profile forbids a `directoryName` SAN
entry.

### Why this is not `XT-008`, `XT-006` or `XT-002`

`XT-008` is the same message but the opposite direction: an unrecognised EKU
*relaxes* the table, producing false negatives on certificates that should be
flagged.

`XT-006` is `GetType` misclassifying which *kind of leaf* a subscriber-profile
check applies to (a delegated OCSP responder judged as a generic TLS
subscriber). `XT-002` is `GetType`'s CA/leaf axis being wrong for a specific
certificate; here the axis is simply not consulted.

### What would fix it

Return from the `directoryName`/`otherName`/`x400Address`/`ediPartyName`/
`registeredID`/`uniformResourceIdentifier` branch of the check — or from
`CheckSAN` before building `name_type_allowed[]` at all — when `type !=
SubscriberCertificate`, on the same pattern the file already uses at
`checks.c:1140` (`bSanRequired` reporting) and `checks.c:1347`
(`WARN_NO_ISSUING_CERT_HTTP`) two functions later.

### How this lane handled it

Not a re-port of `XT-008`'s fix, which corrects the permissive branch this
entry does not turn on. Recorded `answered` for `checks.c::ERR_SAN_TYPE::1` in
`ledger-fragment.json`: `cabf_br/e_ext_san_prohibited_name_type` and the two
S/MIME siblings already carry `tls_scope::governs` / `smime::governs` guards
and apply only to subscriber certificates by construction, so the scope defect
described here has no counterpart to port.

### What was not verified

The 36-certificate residual within the `subscriber`-role population was not
sampled individually — reasoned by analogy to `XT-006`'s established mechanism
rather than confirmed certificate by certificate, on the same "consistent
rather than confirmed" standard `XT-021` used for its own four-certificate
residual.
