"""Regenerate PT-001's four fixtures. Not run by run.sh; kept so the recipe is
inspectable rather than asserted.

    python PT-001-mkfixtures.py [output-dir]

Four subscriber certificates identical in every field but one: the ASN.1
alternative their `explicitText` uses.

positive/PT-001-utf8string.pem DisplayText ::= utf8String positive/PT-001-ia5string.pem
DisplayText ::= ia5String positive/PT-001-visiblestring.pem DisplayText ::=
visibleString positive/PT-001-bmpstring.pem DisplayText ::= bmpString

`DisplayText` has exactly those four alternatives, so between them they are the
whole of the question, and each is one CHOICE tag apart from the others.

All four are issued 2025-01-01, twelve years after RFC 6818 replaced the
paragraph RFC 5280 §4.2.1.4 states this in. That matters: under RFC 5280
`visibleString` and `bmpString` are prohibited and `ia5String` is permitted;
under RFC 6818 it is the other way round. A certificate issued in 2025 is
governed by the replacement.

The certificatePolicies extension is assembled with pyasn1 and attached as an
`UnrecognizedExtension`, because `cryptography`'s own `UserNotice` builder
emits `utf8String` and nothing else — which is the correct thing for it to do
and useless for demonstrating the other three.

Not re-signed after assembly and not signed by a real issuer; pkilint does not
verify a linted certificate's signature, and the utf8String fixture is the
control that shows it.
"""

import base64 import datetime import pathlib import sys

from cryptography import x509 from cryptography.hazmat.primitives import
hashes, serialization from cryptography.hazmat.primitives.asymmetric import
rsa from cryptography.x509.oid import AuthorityInformationAccessOID,
ExtendedKeyUsageOID, NameOID from pyasn1.codec.der.encoder import encode as
der_encode from pyasn1.type import univ from pyasn1_alt_modules import rfc5280

OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")

UTC = datetime.timezone.utc
NOT_BEFORE = datetime.datetime(2025, 1, 1, tzinfo=UTC)
NOT_AFTER = datetime.datetime(2025, 6, 1, tzinfo=UTC)

DV_POLICY = "2.23.140.1.2.1"
ID_QT_UNOTICE = "1.3.6.1.5.5.7.2.2"
TEXT = "PT-001 explicit text"

# `DisplayText ::= CHOICE { ia5String, visibleString, bmpString, utf8String
# }`, RFC 5280 s4.2.1.4. The file name is the lower-cased alternative.
ALTERNATIVES = {
    "utf8string": "utf8String",
    "ia5string": "ia5String",
    "visiblestring": "visibleString",
    "bmpstring": "bmpString",
}

def policies_der(alternative: str) -> bytes:
    """certificatePolicies asserting the DV identifier with one user notice."""
    name = ALTERNATIVES[alternative]

    # The component is cloned from the schema rather than built from a bare
    # char.* class: each alternative of DisplayText carries a SIZE (1..200)
    # subtype, and a value without it is tag-incompatible with the CHOICE.
    display = rfc5280.DisplayText()
    position = display.componentType.getPositionByName(name)
    prototype = display.componentType.getTypeByPosition(position)
    display.setComponentByPosition(position, prototype.clone(TEXT))

    notice = rfc5280.UserNotice()
    notice.setComponentByName("explicitText", display)

    qualifier = rfc5280.PolicyQualifierInfo()
    qualifier.setComponentByName(
        "policyQualifierId", univ.ObjectIdentifier(ID_QT_UNOTICE))
    qualifier.setComponentByName(
        "qualifier", univ.Any(der_encode(notice)))

    info = rfc5280.PolicyInformation()
    info.setComponentByName("policyIdentifier", rfc5280.CertPolicyId(DV_POLICY))
# The SEQUENCE OF is anonymous in the module, so it is taken from the field # rather than named: rfc5280 exports PolicyInformation but no # PolicyQualifiers type of its own.
    info.setComponentByName("policyQualifiers")
    info.getComponentByName("policyQualifiers").setComponentByPosition(0, qualifier)

    policies = rfc5280.CertificatePolicies()
    policies.setComponentByPosition(0, info)
    return der_encode(policies)

def build(alternative: str) -> bytes:
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    return (
        x509.CertificateBuilder()
        .subject_name(x509.Name([
            x509.NameAttribute(NameOID.COUNTRY_NAME, "XX"),
            x509.NameAttribute(NameOID.COMMON_NAME, "pk007.example.com"),
        ]))
        .issuer_name(x509.Name([
            x509.NameAttribute(NameOID.COUNTRY_NAME, "XX"),
            x509.NameAttribute(NameOID.ORGANIZATION_NAME, "PT-001 Test CA"),
            x509.NameAttribute(NameOID.COMMON_NAME, "PT-001 Issuing CA"),
        ]))
        .public_key(key.public_key())
        .serial_number(0x700700700700)
        .not_valid_before(NOT_BEFORE)
        .not_valid_after(NOT_AFTER)
        .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=True)
        .add_extension(
            x509.KeyUsage(
digital_signature=True, content_commitment=False, key_encipherment=False,
data_encipherment=False, key_agreement=False, key_cert_sign=False,
crl_sign=False,
                encipher_only=False, decipher_only=False),
            critical=True)
        .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]), critical=False)
        .add_extension(
            x509.SubjectAlternativeName([x509.DNSName("pk007.example.com")]),
            critical=False)
        .add_extension(x509.AuthorityKeyIdentifier(b"\x00" * 20, None, None), critical=False)
        .add_extension(
            x509.CRLDistributionPoints([
                x509.DistributionPoint(
                    full_name=[x509.UniformResourceIdentifier(
                        "http://crl.example.com/pk007.crl")],
                    relative_name=None, reasons=None, crl_issuer=None)]),
            critical=False)
        .add_extension(
            x509.AuthorityInformationAccess([
                x509.AccessDescription(
                    AuthorityInformationAccessOID.CA_ISSUERS,
                    x509.UniformResourceIdentifier("http://aia.example.com/pk007.crt"))]),
            critical=False)
        .add_extension(
            x509.UnrecognizedExtension(
                x509.ObjectIdentifier("2.5.29.32"), policies_der(alternative)),
            critical=False)
        .sign(key, hashes.SHA256())
        .public_bytes(serialization.Encoding.DER)
    )

def write_pem(path: pathlib.Path, der: bytes) -> None:
    b64 = base64.b64encode(der)
    lines = [b64[i:i + 64].decode() for i in range(0, len(b64), 64)]
    path.write_text("-----BEGIN CERTIFICATE-----\n"
                    + "\n".join(lines)
                    + "\n-----END CERTIFICATE-----\n")
    print(f"wrote {path} ({len(der)} bytes)")

for alternative in ALTERNATIVES:
    write_pem(OUT / f"PT-001-{alternative}.pem", build(alternative))
