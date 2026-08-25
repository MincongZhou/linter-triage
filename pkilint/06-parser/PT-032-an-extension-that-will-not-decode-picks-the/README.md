# PT-032 — an extension that will not decode picks the wrong certificate profile

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `06-parser` — Root cause in the decoder, not in the check |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | `pkilint./repro.sh` (two cases: a fabricated pair one byte apart, and a real certificate) |

## Upstream issues, adjudicated

- **#2** — ECDSA signature checks *(open)*
  **related.** Same decode-failure root cause; this entry is about the failure selecting the wrong PROFILE rather than producing a finding.
- **#138** — lint_pkix_cert produces ASN.1 errors when certificate is version 1 *(closed)*
  **related.** As #2.

## Analysis

pkilint chooses which profile to apply from `determine_certificate_type`,
which branches on `RFC5280Certificate.is_ca`. That property decodes
`basicConstraints` and maps a decode failure to `False`:

```python
def _decode_and_append_extension(self, ext_oid, ext_asn1_spec):
    ...
    except ValueError:
        # suppress decoding errors, which will be reported by DecodingValidator instances
        return None

@functools.cached_property
def is_ca(self) -> bool:
    decoded = self._decode_and_append_extension(
        rfc5280.id_ce_basicConstraints, rfc5280.BasicConstraints())
    return bool(decoded.navigate("cA").pdu) if decoded else False
```

So a CA certificate whose `basicConstraints` will not decode is linted as a
**subscriber certificate**. The comment is right that the failure is reported
— `itu.invalid_asn1_syntax (FATAL)` is emitted in the same run — but the
*blast radius* is not: nothing says the certificate was routed to the wrong
profile.

The two fixtures differ in one byte, `0x05` against `0xfb` in the
`pathLenConstraint`:

```
negative/PT-032-control.pem            CA:TRUE, pathlen:5
  INTERNAL-UNCONSTRAINED-TLS-CA
    cabf.ca_certificate_no_digital_signature_bit (NOTICE)

positive/PT-032-pathlen-negative.pem   CA:TRUE, pathlen:-5
  OV-FINAL-CERTIFICATE
    itu.invalid_asn1_syntax (FATAL)  ... schema "BasicConstraints"
    cabf.serverauth.certificate_validity_period_exceeds_398_days (ERROR)
    cabf.serverauth.subscriber_stateprovince_and_locality_missing (ERROR)
    cabf.serverauth.subscriber_common_name_unknown_source (ERROR)
    pkix.ee_certificate_keycertsign_keyusage_set (ERROR)
    cabf.serverauth.subscriber_prohibited_ku_present (ERROR): keyCertSign
    cabf.serverauth.subscriber.subject_altname_extension_absent (ERROR)
```

**observed** — a CA certificate is judged against the subscriber profile.
Every CA check is skipped, and six subscriber requirements that do not apply
to a CA are reported as errors: a 5-year validity period, absent
stateOrProvince and locality, a commonName with "no source" in a SAN a CA is
not required to have, `keyCertSign` as a prohibited key usage.

**correct** — treat a `basicConstraints` that failed to decode as *unknown*
rather than as absent, and decline to profile the certificate at all. The
information already exists in the same report.

**Why High: the subject of the check decides which checks run.** This is the
`PT-031` shape one level up. There, an undecodable `keyUsage` silences the
keyUsage checks; here, an undecodable `basicConstraints` silences an entire
profile and substitutes a different one. It is the only entry in this file
where pkilint emits findings that are *affirmatively wrong* rather than
absent, which matters for anyone consuming its output as ground truth.

**The trigger is narrow, and was established by running the decoder rather
than by reasoning about it.** Of seven malformed encodings tried, only
`pathLenConstraint < 0` is rejected — pyasn1 enforces RFC 5280's `INTEGER
(0..MAX)`. A BER `BOOLEAN` of `0x01`, an explicitly-encoded `DEFAULT FALSE`,
an empty `SEQUENCE` and trailing data after the `SEQUENCE` are all accepted.
`is_self_issued` is tested before `is_ca`, and a self-issued certificate
carrying the same defect still types `ROOT-CA` — checked by running one — so
this reaches intermediates only.

### The second case, on a real certificate and a different property

`is_ca` is not the only accessor built this way. `policy_oids` and
`extended_key_usages` decode their extensions through the same helper and
render a failure as *empty* — and `_determine_subscriber_certificate_type`
reads `policy_oids`, ending:

```python
else:
    # "unknown" certificate types are considered to be DV Subscriber certs
    return ...DV_FINAL_CERTIFICATE
```

`positive/PT-032-undecodable-policies.pem` asserts `2.23.140.1.2.2`, the
reserved identifier for **organization-validated**, which OpenSSL prints from
the same bytes. Its `certificatePolicies` contains an OID arc larger than 32
bits, so pkilint's decode raises, `cert.policy_oids` returns `[]`, and the
certificate falls through the chain of `elif`s to the DV default:

```
policy_oids: []
DV-FINAL-CERTIFICATE
  itu.invalid_asn1_syntax (FATAL) ... schema "CertificatePolicies"
  cabf.serverauth.dv.unknown_attribute_present (ERROR): 2.5.4.7   localityName
  cabf.serverauth.dv.unknown_attribute_present (ERROR): 2.5.4.10  organizationName
  cabf.serverauth.dv.unknown_attribute_present (ERROR): 2.5.4.8   stateOrProvinceName
```

All three attributes are **permitted in an OV subject** by BR §7.1.2.7.4,
which is the profile the certificate asked for. So a second undecodable
extension produces a second set of confidently wrong errors, by the same
route.

The certificate is real, and came out of measurement rather than out of
looking for this: it was the one residual certificate left when the gate row
`cabf.serverauth.dv.unknown_attribute_present` was read out. It is zlint's
`invalid_cps_uri_ko_03.pem` (Apache-2.0), re-emitted here as plain PEM because
pkilint's PEM loader rejects the text preamble zlint ships it with; the
certificate bytes are unchanged.

**Fix, covering both cases.** Give the three accessors a third state and let
the profile chooser refuse rather than guess. `is_ca` returning `False` for
"could not read" and `policy_oids` returning `[]` for "could not read" are the
same defect at two sites, and the DV fallback turns the second into errors
rather than silence.
