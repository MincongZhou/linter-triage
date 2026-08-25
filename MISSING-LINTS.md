# Requirements none of these four tools checks

Written for the package, not for this tree. Each item says what is unchecked,
why it is unchecked, and — where it matters — a real incident that a check
would have caught.

Three of these are recorded as entries (`09-absent`) because a specific clause
has no message. The rest are here because **no per-certificate linter can
answer them at all**: the evidence is outside the certificate. That distinction
is the point of the list.

---

## A. Clauses with no message in any of the four

**BR § 7.1.4.3, character-for-character.** The Subject attributes of a
Subordinate CA MUST match the Issuing CA's Subject "character-for-character".
No tool emits anything for it; two of them decode both DNs on the way past.
Recorded as `CT-039`.

**BR § 6.1.5, the Subordinate CA disjunction.** The key-size column is a
disjunction and only one branch is linted, so a Subordinate CA taking the other
branch is unexamined. Recorded as `ZT-094`.

**A Subscriber certificate with no `keyUsage` at all.** BR § 7.1.2.7.6 makes it
SHOULD; nothing reports it. Recorded as `ZT-068`.

**RFC 5280 § 4.2.1.10 name constraints, actually applied.** Every tool checks
the *syntax* of a `nameConstraints` extension. None checks that a certificate
issued beneath a technically-constrained CA falls inside those constraints,
because that needs the issuer's certificate.

---

## B. Answerable only with the issuer, or the chain

A linter that takes one file cannot see these. A monitor that keeps the chain
can.

**Cross-certificate exemptions.** MRSP § 5.3 requires an EKU on intermediates
created after 2019-01-01 and exempts cross-certificates that share a private
key with a root. Nothing in the certificate shows the sharing, so all four
tools either report every such intermediate or none. Deciding it needs a
disclosure database keyed on subject and public key.

**BR § 7.1.2.2's precondition.** "The same Subject Name and Subject Public Key
Information as one or more existing CA Certificate(s)." Both fields are in
other certificates.

**Signature verification against the issuer.** No tool here verifies that the
certificate was signed by the key it names. A signature over a modified TBS is
outside every check in this package.

**Path-length arithmetic.** `pathLenConstraint` is checked for encoding, never
against the depth actually issued beneath it.

---

## C. Answerable only across an issuer's population

One certificate cannot be anomalous by itself.

**Serial-number entropy, measured.** BR § 7.1 requires 64 bits of CSPRNG
output. Every tool checks the serial's *length*. Length is not entropy: a CA
emitting a fixed prefix and a 32-bit counter passes every existing check. The
measurable version counts bit positions that ever vary across an issuer's
output, and it needs the issuer's output.

**Shared RSA factors.** A pairwise GCD across all issued moduli finds keys
generated with a broken RNG. Batch GCD makes it tractable; no linter can do it,
because it is a property of a set.

**Issuance-profile divergence.** The DER shape a CA issues — tag skeleton,
extension order, policy identifiers, critical bits — is extremely stable per
issuing CA. A first-of-its-kind shape from a CA that has issued one shape for a
year is worth a look, and is invisible to any tool judging one certificate
against a document.

**CRL shard disclosure.** A `cRLDistributionPoints` URL that is not on the
issuer's disclosed CRL list is a disclosure failure. It needs the disclosure
list, and fetching the URL is not an option — it is attacker-chosen.

---

## D. Answerable only from the log

**A falsified `notBefore`.** Within one certificate the only counter-evidence
is an embedded SCT, and comparing the two is an ordinary lint — zlint has it,
and `ZT-011` records that the lint gates itself on the very field it polices,
so a certificate backdated far enough is not judged by it. Against the log the
question is easy: entries are appended in roughly arrival order, so a
`notBefore` that jumps away from its neighbours is conspicuous with no second
source at all.

**SCT `leaf_index` extensions.** static-ct-api logs attach a `leaf_index`
extension to the SCT. CAs have both mangled it — base64 text in a binary field
— and stripped it, re-encoding an SCT without extensions the log signed over,
so it cannot verify. Detecting the stripped case requires knowing which logs
emit extensions, which is learnable from traffic and is in no linter.

---

## E. Weak keys, which two of these four do not look at

`zlint` carries a Fermat-factorisation lint. `pkilint`, `x509lint` and
`certlint` carry nothing about key quality at all — they check key *size*,
which is a different question. Verified by grep against each pinned tree.

Separate binaries exist for two of these (`dwklint` for the Debian weak-key
list, `rocacheck`), so a deployment that runs a suite may already be covered.
A user who runs one of these four alone is not.

- **ROCA** (CVE-2017-15361). The Infineon RSALib fingerprint is a cheap
  constant-time test on the modulus. Recorded here because it is the clearest
  case of a check that is inexpensive, has a public test vector, and is absent
  from three of the four.
- **Close prime factors.** Fermat's method finds keys whose primes are adjacent
  — an entire class of broken generators.
- **Small or repeated moduli across issuers.**

Real cases exist for each: the 2017 ROCA disclosure forced the replacement of
Estonian and Slovak national ID certificates, and Fermat-factorable keys have
appeared in publicly-trusted issuance more than once.

---

## F. Two the specifications make undecidable, listed so nobody re-derives them

**A wildcard left of a public suffix** is permitted if the applicant proves
control of the suffix. Nothing in the certificate says whether they did.

**Whether an organization name is accurate.** Every check on it is a format
check. This is a validation question, not a certificate question, and no linter
should claim it.
