# ZT-067 — `w_subject_common_name_included` applies the Baseline Requirements' word to EV certificates, whose subject the Baseline Requirements defer

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `08-hygiene` — Descriptions, citations, severities and tests |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | a real EV subscriber certificate, with a real OV one as the control |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

The lint cites `BRs: 7.1.2.7.1` and describes itself as "Subscriber
Certificate: commonName is NOT RECOMMENDED." §7.1.2.7.1 enumerates the four
Subscriber Certificate types, and three of the four carry a `commonName` row
that does read NOT RECOMMENDED. The fourth does not:

> ##### 7.1.2.7.5 Extended Validation
>
> | `subject` | See Guidelines for the Issuance and Management of Extended
> Validation Certificates, Section 7.1.4.2. |

and EVG §7.1.4.2.2, in the text current at `servercert` `ad77bf1`, still
reads:

> **Required/Optional**: Deprecated (Discouraged, but not prohibited)

which is the wording the *other* lint of the pair,
`n_subject_common_name_included`, was written for and reports as a **notice**.
That lint carries `IneffectiveDate: util.SC62EffectiveDate`, so from
2023-09-15 it is `NE` on everything, including the certificates whose
governing document never changed.

The consequence is not that zlint misses the EV-ness. It has it:

| | EV | control (OV) |
|---|---|---|
| `e_ev_business_category_missing` | pass | NA |
| `e_ev_serial_number_missing` | pass | NA |
| `e_ev_organization_name_missing` | pass | NA |
| `e_ev_country_name_missing` | pass | NA |
| `n_subject_common_name_included` | NE | NE |
| `w_subject_common_name_included` | **warn** | **warn** |

Four `cabf_ev` lints run on the subject certificate and decline the control,
so the EV test `CheckApplies` would need is one zlint already makes in eight
places. `commonNamesSC62.CheckApplies` is `util.IsSubscriberCert(c)` and
nothing else.

**Fix**: exclude an EV certificate in `commonNamesSC62.CheckApplies`, and add
a `cabf_ev` notice citing EVG §7.1.4.2.2 to say what that document says. The
pre-SC62 lint's scope is right as it stands: before SC62 the Baseline
Requirements stated `commonName` once, at §7.1.4.2.2, for every subscriber
certificate regardless of type, and both documents said the same word.
