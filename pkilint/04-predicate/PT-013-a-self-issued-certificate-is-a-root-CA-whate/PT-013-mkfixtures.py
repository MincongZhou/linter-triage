"""Regenerate PT-013's fixture pair. Not run by run.sh; kept so the recipe is
inspectable rather than asserted.

    python PT-013-mkfixtures.py [output-dir]

Two end-entity certificates that differ in the issuer name and in nothing
else. Both carry basicConstraints cA:FALSE, an extendedKeyUsage of serverAuth,
a dNSName SAN and the domain-validated reserved policy identifier: subscriber
certificates by every field that says so.

positive/PT-013-self-issued.pem issuer == subject negative/PT-013-control.pem issuer is a
different name

The only difference is the one pkilint's is_self_issued reads, so any
difference in the profile it chooses is attributable to that and to nothing
else. Neither is re-signed after the fact -- both are signed by the same key
as issued -- because pkilint does not verify a linted certificate's signature.
"""

import base64 import datetime import pathlib import sys

from cryptography import x509 from cryptography.hazmat.primitives import
hashes, serialization from cryptography.hazmat.primitives.asymmetric import
rsa from cryptography.x509.oid import AuthorityInformationAccessOID,
ExtendedKeyUsageOID, NameOID

OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")

UTC = datetime.timezone.utc
NOT_BEFORE = datetime.datetime(2025, 1, 1, tzinfo=UTC)
NOT_AFTER = datetime.datetime(2025, 6, 1, tzinfo=UTC)   # 151 days: inside the 398-day maximum

SUBJECT = x509.Name([
    x509.NameAttribute(NameOID.COUNTRY_NAME, "XX"),
    x509.NameAttribute(NameOID.COMMON_NAME, "pk006.example.com"),
])
OTHER_ISSUER = x509.Name([
    x509.NameAttribute(NameOID.COUNTRY_NAME, "XX"),
    x509.NameAttribute(NameOID.ORGANIZATION_NAME, "PT-013 Test CA"),
    x509.NameAttribute(NameOID.COMMON_NAME, "PT-013 Issuing CA"),
])

def build(issuer: x509.Name) -> bytes:
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    return (
        x509.CertificateBuilder()
        .subject_name(SUBJECT)
        .issuer_name(issuer)
        .public_key(key.public_key())
        .serial_number(0x600600600600)
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
            x509.SubjectAlternativeName([x509.DNSName("pk006.example.com")]),
            critical=False)
        .add_extension(
            x509.CertificatePolicies([
                x509.PolicyInformation(x509.ObjectIdentifier("2.23.140.1.2.1"), None)]),
            critical=False)
        .add_extension(
            x509.AuthorityKeyIdentifier(b"\x00" * 20, None, None), critical=False)
        .add_extension(
            x509.CRLDistributionPoints([
                x509.DistributionPoint(
                    full_name=[x509.UniformResourceIdentifier(
                        "http://crl.example.com/pk006.crl")],
                    relative_name=None, reasons=None, crl_issuer=None)]),
            critical=False)
        .add_extension(
            x509.AuthorityInformationAccess([
                x509.AccessDescription(
                    AuthorityInformationAccessOID.CA_ISSUERS,
                    x509.UniformResourceIdentifier("http://aia.example.com/pk006.crt"))]),
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

write_pem(OUT / "positive/PT-013-self-issued.pem", build(SUBJECT))
write_pem(OUT / "negative/PT-013-control.pem", build(OTHER_ISSUER))
