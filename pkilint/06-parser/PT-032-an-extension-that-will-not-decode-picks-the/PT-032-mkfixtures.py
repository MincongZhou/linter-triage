"""Regenerate PT-032's fixture pair. Not run by run.sh; kept so the recipe is
inspectable rather than asserted.

    python PT-032-mkfixtures.py [output-dir]

Two certificates that differ in one byte. Everything else -- keys, serial,
names, validity, every other extension -- is byte-identical, which is what
makes the second one a control: any difference in what pkilint says about them
is attributable to the pathLenConstraint and to nothing else.

negative/PT-032-control.pem pathLenConstraint = 5 positive/PT-032-pathlen-negative.pem
pathLenConstraint = -5

-5 is a DER-valid INTEGER outside RFC 5280's `INTEGER (0..MAX)`, which is the
one encoding pyasn1 rejects here; ./repro.sh prints the six it accepts.

The edit is made to the signed DER and the certificate is not re-signed, so
the signature is invalid on both. That is deliberate and it is why the control
matters: pkilint does not verify a linted certificate's signature, and the
control demonstrates it by being linted normally.

The validity period is five years -- lawful for a CA, and four times the
subscriber maximum -- so that a certificate mistyped as a subscriber says so
out loud.
"""

import base64 import datetime import pathlib import sys

from cryptography import x509 from cryptography.hazmat.primitives import
hashes, serialization from cryptography.hazmat.primitives.asymmetric import
rsa from cryptography.x509.oid import AuthorityInformationAccessOID,
ExtendedKeyUsageOID, NameOID

OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")

UTC = datetime.timezone.utc
NOT_BEFORE = datetime.datetime(2024, 1, 1, tzinfo=UTC)
NOT_AFTER = datetime.datetime(2029, 1, 1, tzinfo=UTC)

# BasicConstraints ::= SEQUENCE { cA BOOLEAN TRUE, pathLenConstraint INTEGER
# }
GOOD = bytes.fromhex("30060101ff020105")   # pathLenConstraint = 5
BAD = bytes.fromhex("30060101ff0201fb")    # pathLenConstraint = -5

def build() -> bytes:
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    parent = rsa.generate_private_key(public_exponent=65537, key_size=2048)

    def name(cn):
        return x509.Name([
            x509.NameAttribute(NameOID.COUNTRY_NAME, "XX"),
            x509.NameAttribute(NameOID.ORGANIZATION_NAME, "PT-032 Test CA"),
            x509.NameAttribute(NameOID.COMMON_NAME, cn),
        ])

    cert = (
        x509.CertificateBuilder()
        .subject_name(name("PT-032 Issuing CA"))
        .issuer_name(name("PT-032 Root CA"))
        .public_key(key.public_key())
        .serial_number(0x5005)
        .not_valid_before(NOT_BEFORE)
        .not_valid_after(NOT_AFTER)
        .add_extension(x509.BasicConstraints(ca=True, path_length=5), critical=True)
        .add_extension(
            x509.KeyUsage(
digital_signature=False, content_commitment=False, key_encipherment=False,
data_encipherment=False, key_agreement=False, key_cert_sign=True,
crl_sign=True,
                encipher_only=False, decipher_only=False),
            critical=True)
        .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]), critical=False)
        .add_extension(x509.SubjectKeyIdentifier.from_public_key(key.public_key()), critical=False)
        .add_extension(
            x509.AuthorityKeyIdentifier.from_issuer_public_key(parent.public_key()),
            critical=False)
        .add_extension(
            x509.CertificatePolicies([
                x509.PolicyInformation(x509.ObjectIdentifier("2.23.140.1.2.2"), None)]),
            critical=False)
        .add_extension(
            x509.CRLDistributionPoints([
                x509.DistributionPoint(
                    full_name=[x509.UniformResourceIdentifier(
                        "http://crl.example.com/pk005.crl")],
                    relative_name=None, reasons=None, crl_issuer=None)]),
            critical=False)
        .add_extension(
            x509.AuthorityInformationAccess([
                x509.AccessDescription(
                    AuthorityInformationAccessOID.CA_ISSUERS,
                    x509.UniformResourceIdentifier("http://aia.example.com/pk005.crt")),
                x509.AccessDescription(
                    AuthorityInformationAccessOID.OCSP,
                    x509.UniformResourceIdentifier("http://ocsp.example.com"))]),
            critical=False)
        .sign(parent, hashes.SHA256())
    )
    return cert.public_bytes(serialization.Encoding.DER)

def write_pem(path: pathlib.Path, der: bytes) -> None:
    b64 = base64.b64encode(der)
    lines = [b64[i:i + 64].decode() for i in range(0, len(b64), 64)]
    path.write_text("-----BEGIN CERTIFICATE-----\n"
                    + "\n".join(lines)
                    + "\n-----END CERTIFICATE-----\n")
    print(f"wrote {path} ({len(der)} bytes)")

der = build()
if der.count(GOOD) != 1:
    raise SystemExit(f"expected exactly one {GOOD.hex()} in the DER, found {der.count(GOOD)}")

write_pem(OUT / "negative/PT-032-control.pem", der)
write_pem(OUT / "positive/PT-032-pathlen-negative.pem", der.replace(GOOD, BAD))
