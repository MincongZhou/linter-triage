# XT-010 — a duplicated extension is reported as an absent one

| | |
|---|---|
| **Tool** | `kroeckx/x509lint` at `103c92f` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ |
| **Verified against** | zlint's own fixture |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```
$ x509lint positive/XT-010-duplicated-akid.pem     # authorityKeyIdentifier appears twice
E: Duplicate extension
E: AKID missing                            <- observed; the extension is present
```

RFC 5280 § 4.2 forbids more than one instance of an extension, which is what
*Duplicate extension* says. *AKID missing* is a second statement about the
same field and it is false.

`GetType` reads the extension with `X509_get_ext_d2i(x509,
NID_authority_key_identifier, &critical, NULL)` (`checks.c:1898`). With a NULL
index argument OpenSSL returns NULL and sets the critical out-param to **-2**,
its code for *extension occurs more than once*. The guard on the next line
tests `critical >= 0`, so -2 passes through it and the absent-extension branch
runs.

`XT-010-get-ext-d2i.c` executes that, and the fixture is its own control — two
of its extensions are duplicated and two are not:

```
authorityKeyIdentifier     occurs 2  ->  NULL     critical out-param = -2
subjectKeyIdentifier       occurs 2  ->  NULL     critical out-param = -2
keyUsage                   occurs 1  ->  non-NULL critical out-param = 1
basicConstraints           occurs 1  ->  non-NULL critical out-param = 1
```

Four call sites pass NULL for the index and take the absent branch on a
duplicate: `keyUsage` (`1464`, skipping the whole `CheckKeyUsage` body),
`basicConstraints` (`1632`, which becomes `ERR_NO_BASIC_CONSTRAINTS` for a CA
and silence for a leaf), `subjectKeyIdentifier` (`1877`) and
`authorityKeyIdentifier` (`1898`). The other five — `certificatePolicies`,
`subjectAltName`, `crlDistributionPoints`, `authorityInformationAccess`,
`extendedKeyUsage` — pass `&idx` and iterate, and are unaffected. This is four
call sites, not the tool's approach.

**What caps this at Medium**: no verdict flips. `ERR_DUPLICATE_EXTENSION`
(`1450`) is raised for any repeated OID before any of this, so a duplicating
certificate always earns at least one error. What is lost is *which*
requirement was broken; what is gained is a false statement about the
certificate. It is not the `XT-008`/`XT-002` shape, where the subject switches
a check off and escapes.

Fix: -2 is not absence. Test for it before the absent branch, at all four
sites, or pass an index and iterate as the other five already do.
