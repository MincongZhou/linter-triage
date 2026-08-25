#!/bin/bash
# ZT-051 — three lints abstain on a SEQUENCE OF that is well-formed and
# empty, because their walker is a do-while that unmarshals one element
# before asking whether any element is there. The shape, in v3/util/oid.go
# GetMappedPolicies and in the copy inside
# lint_ext_cert_policy_disallowed_any_policy_qualifier.go: for done :=
# false; !done; { seq.Bytes, err = asn1.Unmarshal(seq.Bytes, &inner) // runs
# first if err != nil { return errors.New("Could not unmarshal ...") } if
# len(seq.Bytes) == 0 { done = true } // asks second ... } With zero
# elements the first Unmarshal is handed an empty slice, returns "sequence
# truncated", and the walker reports that it could not unmarshal bytes that
# in fact decoded cleanly. The three affected lints are
# e_ext_cert_policy_disallowed_any_policy_qualifier (its own copy)
# e_ext_policy_map_any_policy (GetMappedPolicies)
# w_ext_policy_map_not_in_cert_policy (GetMappedPolicies) zlint settles the
# question against itself. An empty SEQUENCE OF is a SIZE (1..MAX)
# violation, and zlint has a lint that says so —
# e_ext_cannot_be_empty_sequence returns *error*, a verdict. Case 2 below
# shows that lint answering the same certificate correctly while the two
# walker lints return fatal on it, so fatal here is not a house convention
# for a schema violation; it is a loop that cannot express zero.
set -u
Z=${ZLINT:-$HOME/.local/bin/zlint}
D=$(dirname "$0")
echo "zlint: $($Z -version 2>&1 | head -1)"

echo
echo "-- case 1: anyPolicy with policyQualifiers present and empty --"
echo "   certificatePolicies of a real Government of Korea GPKI root:"
echo "   30 0a 30 08 06 04 55 1d 20 00 30 00"
echo "     SEQUENCE { SEQUENCE { OID 2.5.29.32.0 anyPolicy, SEQUENCE {} } }"
$Z -includeNames=e_ext_cert_policy_disallowed_any_policy_qualifier \
   "$D/positive/ZT-051-anypolicy-empty-qualifiers.der" 2>/dev/null
echo "   control, anyPolicy carrying one CPS qualifier:"
$Z -includeNames=e_ext_cert_policy_disallowed_any_policy_qualifier \
   "$D/negative/ZT-051-control-anypolicy-one-cps-qualifier.pem" 2>/dev/null

echo
echo "-- case 2: policyMappings present and empty --"
echo "   the same certificate, judged by three lints:"
$Z -includeNames=e_ext_cannot_be_empty_sequence,e_ext_policy_map_any_policy,w_ext_policy_map_not_in_cert_policy \
   "$D/positive/ZT-051-empty-policy-mappings.pem" 2>/dev/null
echo "   control, one well-formed mapping pair:"
$Z -includeNames=e_ext_cannot_be_empty_sequence,e_ext_policy_map_any_policy,w_ext_policy_map_not_in_cert_policy \
   "$D/negative/ZT-051-control-policy-mappings-one-pair.pem" 2>/dev/null

echo
echo "observed: fatal, 'Could not unmarshal policy qualifiers' / 'inner sequence'"
echo "correct : pass  — no qualifier is asserted, so none is disallowed; and no"
echo "          issuerDomainPolicy is mapped, so none is unasserted. The"
echo "          SIZE (1..MAX) violation belongs to e_ext_cannot_be_empty_sequence,"
echo "          which reports it."
echo "fix     : test for the end of the sequence before decoding an element —"
echo "          for len(seq.Bytes) > 0 { ... } — in GetMappedPolicies and in the"
echo "          copy of it inside the anyPolicy-qualifier lint."
echo
echo "note    : e_ext_cannot_be_empty_sequence tests only the extension's own"
echo "          top-level SEQUENCE, so the nested empty policyQualifiers in"
echo "          case 1 is reported by nothing. Case 1's certificate draws no"
echo "          finding from any zlint lint about it."
