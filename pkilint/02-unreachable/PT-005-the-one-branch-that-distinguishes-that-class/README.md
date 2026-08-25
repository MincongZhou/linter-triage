# PT-005 — the one branch that distinguishes that class raises `TypeError` on a `set`

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `02-unreachable` — Checks that cannot fire |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | latent: unreachable while PT-004 stands |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

Inside the same class, `validate` (`certificate_extension.py:108–112`):

```python
if not self._allow_other_policies:
    all_specified_policies = set()
    for policy_set in self._policy_sets:
        all_specified_policies += policy_set.policies
```

`set` implements no `__iadd__` and no `__add__`:

```
$ python3 -c "s=set(); s += {1,2}"
TypeError: unsupported operand type(s) for +=: 'set' and 'set'
```

The intended operator is `|=` (or `.update`). As written, the loop raises on its **first iteration** whenever `_policy_sets` is non-empty — which is every configuration in which the class does anything, since `_policy_sets` is the thing it checks against.

This is the `pk-f` shape twice over, because of what guards it. In `__init__`:

```python
if not allow_other_policies:
    validations.append(self.VALIDATION_UNKNOWN_POLICY_OID)
```

`pkix.unknown_certificate_policy_oid` is **installed only under
`allow_other_policies=False`**, and `allow_other_policies=False` is **exactly
the branch that raises**. Even if PT-004 were fixed by wiring the class up,
that code could still never be emitted: the condition that installs it is the
condition that crashes before it.

The exception would surface as `base.unhandled_exception` — pkilint catches
validator exceptions rather than propagating them — so the failure mode is a
generic FATAL on the certificate, not a traceback.

The one configuration that does not raise is `_policy_sets == []`, where the
loop body never runs; `other_policies` is then the whole policy set and
*every* policy is reported unknown. That is a degenerate configuration, not a
working one.

observed `set += set` — TypeError on first iteration correct `all_specified_policies |= policy_set.policies`

Fixing PT-004 alone leaves this live, which is why it is a separate entry.
