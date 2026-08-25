#!/usr/bin/env python3
"""The recipe for ZT-019's certificate pair.

Two qualified certificates issued to a natural person under QCP-n, carrying no
keyUsage extension, differing only in notBefore:

2018-03-14 inside EN 319 412-2 v2.1.1, before zlint's date NE 2020-08-01 after
zlint's date error

Everything about the pair except notBefore/notAfter is identical, including
the key, so the only thing the lint has to judge differently is the date.

    python3 ZT-019-build.py        # rewrites the two PEMs beside this file

Requires `cryptography`; the version is printed, because this tree has been
caught before by a parser whose leniency changed between releases.
"""

from __future__ import annotations

import datetime import pathlib

import cryptography from cryptography import x509 from
cryptography.hazmat.primitives import hashes, serialization from
cryptography.hazmat.primitives.asymmetric import ec from cryptography.x509.oid
import NameOID

HERE = pathlib.Path(__file__).resolve().parent

# QCP-n, EN 319 411-2: a qualified certificate issued to a natural person.
# util.QCPnPolicyOID, and on its own enough for util.IsEtsiQcNaturalPerson.
QCP_N = x509.ObjectIdentifier("0.4.0.194112.1.0")

# A fixed key, so the two certificates differ in nothing but their dates.
# Not secret and not reused anywhere: it exists to make the pair signable.
KEY_PEM = b"""-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgtsbUSQ+3raK/VNk0
FIzvGzejheTvfHj1kZ66Ujtyh4mhRANCAAQoziXYA7EtWQveaEjl6pRRPkZfAFxt
vy9Ao0JTsTW1r+xSUvfLihzKLkFFXAnNjBVBKCGVRqdTh/c/VWIPY+Es -----END PRIVATE
KEY-----
"""

def certificate(not_before: datetime.datetime) -> bytes:
    """One certificate of the pair, as PEM."""
    key = serialization.load_pem_private_key(KEY_PEM, password=None)
    name = x509.Name(
        [
            x509.NameAttribute(NameOID.COUNTRY_NAME, "PL"),
            x509.NameAttribute(NameOID.SURNAME, "Nowak"),
            x509.NameAttribute(NameOID.GIVEN_NAME, "Alexandra"),
            x509.NameAttribute(NameOID.COMMON_NAME, "Alexandra Nowak"),
        ]
    )
    issuer = x509.Name(
        [
            x509.NameAttribute(NameOID.COUNTRY_NAME, "PL"),
            x509.NameAttribute(NameOID.ORGANIZATION_NAME, "ZT-019 synthetic issuer"),
            x509.NameAttribute(NameOID.COMMON_NAME, "ZT-019 synthetic issuer -- not a real CA"),
        ]
    )
    builder = (
        x509.CertificateBuilder()
        .subject_name(name)
        .issuer_name(issuer)
        .public_key(key.public_key())
        .serial_number(0x4B1D8E63A72C59F0)
        .not_valid_before(not_before)
        .not_valid_after(not_before + datetime.timedelta(days=365))
# QCP-n alone. util.IsEtsiQcNaturalPerson returns true on it without # consulting the subject, so the given name and surname above are # realism rather than load-bearing.
        .add_extension(
            x509.CertificatePolicies(
                [x509.PolicyInformation(policy_identifier=QCP_N, policy_qualifiers=None)]
            ),
            critical=False,
        )
        .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=True)
        .add_extension(
            x509.SubjectAlternativeName([x509.RFC822Name("alexandra.nowak@example.com")]),
            critical=False,
        )
        .add_extension(
            x509.ExtendedKeyUsage([x509.ObjectIdentifier("1.3.6.1.5.5.7.3.4")]),
            critical=False,
        )
# No keyUsage. That absence is the whole of it: NAT-4.3.2-1 says the # extension shall be present.
    )
    return builder.sign(key, hashes.SHA256()).public_bytes(serialization.Encoding.PEM)

def main() -> None:
    print(f"cryptography {cryptography.__version__}")
    utc = datetime.timezone.utc
    for stamp, name in (
        (datetime.datetime(2018, 3, 14, tzinfo=utc), "positive/ZT-019-qcp-n-no-keyusage-2018.pem"),
        (datetime.datetime(2020, 8, 1, tzinfo=utc), "negative/ZT-019-control-2020-08-01.pem"),
    ):
        (HERE / name).write_bytes(certificate(stamp))
        print(f"wrote {name}  notBefore {stamp:%Y-%m-%d}")

if __name__ == "__main__":
    main()
