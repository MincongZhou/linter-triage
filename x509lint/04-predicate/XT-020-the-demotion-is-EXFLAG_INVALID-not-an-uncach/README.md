# XT-020 — the demotion is `EXFLAG_INVALID`, not an uncached `EXFLAG_CA`; one content octet in *any* extension re-profiles a root as a leaf

| | |
|---|---|
| **Tool** | `kroeckx/x509lint` at `103c92f` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

### The one-octet pair

Two self-signed certificates, `cA:TRUE`, `keyCertSign` asserted — so
`XT-002`'s early return does not apply to either — differing in exactly one
octet of the `TBSCertificate`: the `GeneralName` tag inside `nameConstraints`'
`permittedSubtree`, `[2] dNSName` (`0x82`) against universal INTEGER (`0x02`).

```
control   E: SKID missing
          I: Checking as root CA certificate

subject   E: Subject with organizationName ... without stateOrProvince or localityName
          E: No policy extension
          E: No Subject alternative name extension
          E: The certificate is valid for longer than 60 months
          E: No CRL or OCSP over HTTP
          E: no authorityInformationAccess extension
          E: Key usage has keyCertSign
          E: AKID missing
          W: No HTTP URL for issuing certificate
          W: Subscriber certificate without Extended Key Usage
          I: Subject has a deprecated CommonName
          I: Unknown validation policy
          I: Checking as leaf certificate
```

One octet costs the true finding, buys eight spurious errors and two spurious
warnings, and one of the errors — `Key usage has keyCertSign` — reports as a
defect the bit BR § 7.1.2.10.7 requires of every CA.

### The mechanism, executed

```
./exflags XL-T-x5-j-03-nameconstraints-good.pem XL-T-x5-j-03-nameconstraints-bad.pem

good  bc.CA=TRUE keyCertSign=yes X509_check_ca()=1
      ex_flags=0x00012133  INVALID=0 BCONS=1 EXFLAG_CA=1 KUSAGE=1
bad   bc.CA=TRUE keyCertSign=yes X509_check_ca()=0
      ex_flags=0x000121b3  INVALID=1 BCONS=1 EXFLAG_CA=1 KUSAGE=1
```

`EXFLAG_CA` is set on both. `EXFLAG_BCONS` is set on both. The single flag
that differs is `EXFLAG_INVALID`, and `./extprobe` shows what set it:

```
X509v3 Basic Constraints   d2i=ok
X509v3 Key Usage           d2i=ok
X509v3 Name Constraints    d2i=FAIL
```

`X509_check_ca` never reaches `check_ca`:

```c
int X509_check_ca(X509 *x)
{
    /* Note 0 normally means "not a CA" - but return 0 on error as well */
    if (!ossl_x509v3_cache_extensions(x))
        return 0;
    return check_ca(x);
}
```

and `ossl_x509v3_cache_extensions` returns `(x->ex_flags & EXFLAG_INVALID) ==
0`. So **any** condition that sets `EXFLAG_INVALID` anywhere in extension
caching — a malformed `nameConstraints`, `keyUsage`, `authorityKeyIdentifier`,
`subjectKeyIdentifier`, `crlDistributionPoints` or `extendedKeyUsage`, a
negative `pathLenConstraint`, a name whose canonical encoding will not build —
makes `X509_check_ca` return 0 and `GetType` return `SubscriberCertificate`,
whatever `basicConstraints` says. The demotion is not specific to
`basicConstraints` and not specific to any one extension.

The root cause is a two-valued return being asked a three-valued question:
`X509_check_ca`'s own comment says "0 normally means *not a CA* — but return 0
on error as well", and `GetType` reads 0 as *not a CA*.

### It also breaks `self_signed`, which is a second output of the same function

`GetType` computes `self_issued = X509_check_issued(x509, x509) == X509_V_OK`,
and that call has the same guard:

```
./selfprobe XL-T-x5-j-03-nameconstraints-{good,bad}.pem
  good  X509_check_issued(self,self)=0 (ok)
  bad   X509_check_issued(self,self)=1 (unspecified certificate verification error)
```

which is why the subject draws `E: AKID missing`. RFC 5280 § 4.2.1.1 expressly
permits a self-signed certificate to omit the `authorityKeyIdentifier`, and
the subject *is* self-signed. One malformed extension therefore corrupts two
of `GetType`'s three outputs, and one of them is an emission site in its own
right — `checks.c::ERR_AKID_MISSING::1`.

### The corpus census, both directions

| cause | count |
|---|---|
| `keyCertSign` absent, `EXFLAG_INVALID` clear — `XT-002`'s route | 56 |
| `keyCertSign` absent **and** `EXFLAG_INVALID` set — both routes | 9 |
| `keyCertSign` **asserted**, `EXFLAG_INVALID` set — this route alone | **18** |

### Fix

```c
BASIC_CONSTRAINTS *bc = X509_get_ext_d2i(x509, NID_basic_constraints, NULL, NULL);
int ca = (bc != NULL && bc->ca) || X509_check_ca(x509);
```

Same for `self_signed`: compare the issuer and subject encodings directly
rather than through `X509_check_issued`, whose "not issued by" value and whose
error value are both non-zero and indistinguishable at this call site.

### How this lane handled it

The consequence for `checks.c::ERR_AKID_MISSING::1` is recorded in that site's
ledger note.
