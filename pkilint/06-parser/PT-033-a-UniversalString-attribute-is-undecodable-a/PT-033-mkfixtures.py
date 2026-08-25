"""Regenerate PT-033's three fixtures. Not run by run.sh; kept so the recipe is
inspectable rather than asserted.

    python PT-033-mkfixtures.py [output-dir]

Three subscriber certificates identical in every field but one: the ASN.1
alternative their `commonName` attribute value uses.

positive/PT-033-printablestring.pem X520CommonName ::= printableString
positive/PT-033-bmpstring.pem X520CommonName ::= bmpString positive/PT-033-universalstring.pem
X520CommonName ::= universalString

`X520CommonName` is a `DirectoryString` CHOICE with five alternatives --
teletexString, printableString, universalString, utf8String, bmpString -- and
BR s7.1.4.2 requires `commonName` to use `UTF8String` or `PrintableString`.
So the printableString fixture must lint clean, and the other two must both
draw `cabf.serverauth.attribute_value_invalid_encoding_type`. Only one of them
does: pkilint cannot load the universalString certificate at all.

The three differ in one TLV. The subject is assembled with pyasn1 and spliced
into a certificate `cryptography` built, because `cryptography` will not emit
`universalString` for a name attribute -- which is the correct thing for it to
do and useless for demonstrating this. The splice is a pyasn1 decode of the
whole certificate, one component replaced, and a re-encode; `check()` below
asserts the round trip is byte-identical before anything is replaced, so the
re-encode is not quietly rewriting fields the fixture does not mean to change.

Not re-signed after assembly. pkilint does not verify a linted certificate's
signature, and the printableString fixture is the control that shows it.
"""

import base64 import datetime import pathlib import sys

from cryptography import x509 from cryptography.hazmat.primitives import
hashes, serialization from cryptography.hazmat.primitives.asymmetric import
rsa from cryptography.x509.oid import AuthorityInformationAccessOID,
ExtendedKeyUsageOID, NameOID from pyasn1.codec.der.decoder import decode as
der_decode from pyasn1.codec.der.encoder import encode as der_encode from
pyasn1.type import univ from pyasn1_alt_modules import rfc5280

OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")

UTC = datetime.timezone.utc
NOT_BEFORE = datetime.datetime(2025, 1, 1, tzinfo=UTC)
NOT_AFTER = datetime.datetime(2025, 6, 1, tzinfo=UTC)

DV_POLICY = "2.23.140.1.2.1"
HOST = "pk008.example.com"

# The file name is the lower-cased CHOICE alternative.
ALTERNATIVES = {
    "printablestring": "printableString",
    "bmpstring": "bmpString",
    "universalstring": "universalString",
}

def subject_name(alternative: str) -> rfc5280.Name:
    """C=XX, CN=<HOST>, with the commonName in the named alternative."""
    name = rfc5280.Name()
    rdns = rfc5280.RDNSequence()

    country = rfc5280.AttributeTypeAndValue()
    country.setComponentByName("type", rfc5280.AttributeType("2.5.4.6"))
    country.setComponentByName(
        "value", univ.Any(der_encode(rfc5280.X520countryName("XX"))))
    first = rfc5280.RelativeDistinguishedName()
    first.setComponentByPosition(0, country)

# Cloned from the schema rather than built from a bare char.* class: each # alternative of DirectoryString carries a SIZE subtype, and a value # without it is tag-incompatible with the CHOICE.
    display = rfc5280.X520CommonName()
    position = display.componentType.getPositionByName(alternative)
    prototype = display.componentType.getTypeByPosition(position)
    display.setComponentByPosition(position, prototype.clone(HOST))

    common = rfc5280.AttributeTypeAndValue()
    common.setComponentByName("type", rfc5280.AttributeType("2.5.4.3"))
    common.setComponentByName("value", univ.Any(der_encode(display)))
    second = rfc5280.RelativeDistinguishedName()
    second.setComponentByPosition(0, common)

    rdns.setComponentByPosition(0, first)
    rdns.setComponentByPosition(1, second)
    name.setComponentByPosition(0, rdns)
    return name

def base_certificate() -> bytes:
    """The certificate every fixture is a one-attribute edit of."""
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    return (
        x509.CertificateBuilder()
        .subject_name(x509.Name([
            x509.NameAttribute(NameOID.COUNTRY_NAME, "XX"),
            x509.NameAttribute(NameOID.COMMON_NAME, HOST),
        ]))
        .issuer_name(x509.Name([
            x509.NameAttribute(NameOID.COUNTRY_NAME, "XX"),
            x509.NameAttribute(NameOID.ORGANIZATION_NAME, "PT-033 Test CA"),
            x509.NameAttribute(NameOID.COMMON_NAME, "PT-033 Issuing CA"),
        ]))
        .public_key(key.public_key())
        .serial_number(0x800800800800)
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
            x509.SubjectAlternativeName([x509.DNSName(HOST)]), critical=False)
        .add_extension(x509.AuthorityKeyIdentifier(b"\x00" * 20, None, None), critical=False)
        .add_extension(
            x509.CertificatePolicies([
                x509.PolicyInformation(x509.ObjectIdentifier(DV_POLICY), None)]),
            critical=False)
        .add_extension(
            x509.CRLDistributionPoints([
                x509.DistributionPoint(
                    full_name=[x509.UniformResourceIdentifier(
                        "http://crl.example.com/pk008.crl")],
                    relative_name=None, reasons=None, crl_issuer=None)]),
            critical=False)
        .add_extension(
            x509.AuthorityInformationAccess([
                x509.AccessDescription(
                    AuthorityInformationAccessOID.CA_ISSUERS,
                    x509.UniformResourceIdentifier("http://aia.example.com/pk008.crt"))]),
            critical=False)
        .sign(key, hashes.SHA256())
        .public_bytes(serialization.Encoding.DER)
    )

def build(base: bytes, alternative: str) -> bytes:
    cert, rest = der_decode(base, asn1Spec=rfc5280.Certificate())
    assert not rest, "trailing data in the base certificate"
    assert der_encode(cert) == base, (
        "pyasn1 does not round-trip the base certificate; the splice below "
        "would be changing more than the subject")
    cert["tbsCertificate"]["subject"] = subject_name(alternative)
    return der_encode(cert)

def write_pem(path: pathlib.Path, der: bytes) -> None:
    b64 = base64.b64encode(der)
    lines = [b64[i:i + 64].decode() for i in range(0, len(b64), 64)]
    path.write_text("-----BEGIN CERTIFICATE-----\n"
                    + "\n".join(lines)
                    + "\n-----END CERTIFICATE-----\n")
    print(f"wrote {path} ({len(der)} bytes)")

base = base_certificate()
for stem, alternative in ALTERNATIVES.items():
    write_pem(OUT / f"PT-033-{stem}.pem", build(base, alternative))
