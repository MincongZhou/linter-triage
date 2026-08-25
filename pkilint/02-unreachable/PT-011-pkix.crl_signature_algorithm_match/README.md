# PT-011 — `pkix.crl_signature_algorithm_match` can never fire

| | |
|---|---|
| **Tool** | `digicert/pkilint` at `0.13.3` |
| **Group** | `02-unreachable` — Checks that cannot fire |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | `pkilint 0.13.3`, reproduced on a fabricated `CertificateList` |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

`SignatureAlgorithmMatchValidator` (`pkilint/pkix/crl/crl_validator.py`)
exists to enforce RFC 5280 § 5.1.2.2: `tbsCertList.signature` MUST be the same
`AlgorithmIdentifier` as the outer `CertificateList.signatureAlgorithm`.

```python
class SignatureAlgorithmMatchValidator(validation.DEREqualityValidator):
    def __init__(self):
        super().__init__(
            other_node_retriever=(lambda n: n.navigate("^.tbsCertList.signature")),
            path="signatureAlgorithm",
            validation=validation.ValidationFinding(
                validation.ValidationFindingSeverity.ERROR,
                "pkix.crl_signature_algorithm_match",
            ),
        )
```

`Validator.match` (`pkilint/document.py`) requires `self._path == node.path`
before a node is even offered to the validator:

```python
def match(self, node):
    if self._path is not None and self._path != node.path:
        return False
    ...
```

Every sibling validator in the same file uses the full path from the document
root — `CorrectVersionValidator` uses `"certificateList.tbsCertList.version"`
three lines above this class — and the outer signature algorithm's actual node
path is `certificateList.signatureAlgorithm`, confirmed by walking a decoded
`CertificateList` (see reproduction). Because the class is registered in
`create_pkix_crl_validator_container` unconditionally (both `--profile PKIX`
and `--profile BR`), it runs on every CRL pkilint ever lints — and `match`
returns `False` every time, so `validate` is never called on any node and the
finding can never be raised.

```python
# encoder: tlv/seq/integer/oid/algid helpers build DER by hand; a CertificateList
# whose tbsCertList.signature and outer signatureAlgorithm name different
# algorithms (sha256WithRSAEncryption outer, sha384WithRSAEncryption inner) —
# the exact shape the clause forbids.
from pkilint import pkix
from pkilint.pkix import crl, name, extension as ext_mod

doc_validator = crl.create_pkix_crl_validator_container(
    [pkix.create_attribute_decoder(name.ATTRIBUTE_TYPE_MAPPINGS),
     pkix.create_extension_decoder(ext_mod.EXTENSION_MAPPINGS)],
    [crl.create_issuer_validator_container([]),
     crl.create_validity_validator_container([]),
     crl.create_extensions_validator_container([])],
)
doc = crl.RFC5280CertificateList(der, der)  # der built with mismatched algids
doc.decode()
for res in doc_validator.validate(doc.root):
    for fd in res.finding_descriptions:
        print(fd.finding.code, fd.message)

# Confirm the actual node path, independently:
def walk(node, depth=0):
    print("  " * depth, node.path)
    for child in node.children.values():
        walk(child, depth + 1)
walk(doc.root)
```

```
(nothing from pkix.crl_signature_algorithm_match — only pkix.name_empty,
 an unrelated finding from this fixture's empty issuer Name)

 certificateList
   certificateList.tbsCertList
     certificateList.tbsCertList.signature
       ...
   certificateList.signatureAlgorithm
     ...
```

**Observed** — no finding, on a `CertificateList` whose two algorithm
identifiers are `sha256WithRSAEncryption` (outer) and
`sha384WithRSAEncryption` (inner). **Correct** —
`pkix.crl_signature_algorithm_match`, ERROR, since RFC 5280 § 5.1.2.2 states
the requirement as a MUST and this is exactly the disagreement it forbids.

**Suggested repair.** `path="certificateList.signatureAlgorithm"`, matching
every sibling validator's convention in the same file.
