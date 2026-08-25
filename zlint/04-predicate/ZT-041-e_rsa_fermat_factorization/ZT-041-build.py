#!/usr/bin/env python3
"""The recipe for ZT-041's certificate pair.

Two 2048-bit RSA certificates differing only in their modulus:

    n = p * p  (p == q)              pass    <- the defect
    n = p * q, q - p = 240           error   control

Both are genuine products of primes found by Miller-Rabin, both exactly 2048
bits so neither trips a size rule, and both are signed by a throwaway EC key
because nothing in either lint verifies a signature.

    python3 ZT-041-build.py        # rewrites the two PEMs beside this file

Requires `cryptography`; the version is printed, because this tree has been
caught before by a parser whose leniency changed between releases.
"""

from __future__ import annotations

import datetime import math import pathlib import random

import cryptography from cryptography import x509 from
cryptography.hazmat.primitives import hashes, serialization from
cryptography.hazmat.primitives.asymmetric import ec from
cryptography.hazmat.primitives.asymmetric.rsa import RSAPublicNumbers from
cryptography.x509.oid import NameOID

HERE = pathlib.Path(__file__).resolve().parent

def probable_prime(n: int, rounds: int = 40) -> bool:
    """Miller-Rabin. Enough for a fixture; not enough for a key."""
    if n < 2:
        return False
    for small in (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37):
        if n % small == 0:
return n == small d, r = n - 1, 0
    while d % 2 == 0:
d //= 2 r += 1
    for _ in range(rounds):
        a = random.randrange(2, n - 1)
        x = pow(a, d, n)
        if x in (1, n - 1):
            continue
        for _ in range(r - 1):
            x = x * x % n
            if x == n - 1:
                break
        else:
return False return True

def next_prime(n: int) -> int:
    if n % 2 == 0:
        n += 1
    while not probable_prime(n):
n += 2 return n

def certificate(modulus: int, common_name: str, serial: int) -> bytes:
    """A minimal subscriber certificate carrying this modulus."""
    signer = ec.generate_private_key(ec.SECP256R1())
    name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, common_name)])
    utc = datetime.timezone.utc
    return (
        x509.CertificateBuilder()
        .subject_name(name)
        .issuer_name(name)
        .public_key(RSAPublicNumbers(65537, modulus).public_key())
        .serial_number(serial)
        .not_valid_before(datetime.datetime(2024, 1, 1, tzinfo=utc))
        .not_valid_after(datetime.datetime(2024, 6, 1, tzinfo=utc))
        .add_extension(
            x509.SubjectAlternativeName([x509.DNSName(common_name)]), critical=False
        )
        .sign(signer, hashes.SHA256())
        .public_bytes(serialization.Encoding.PEM)
    )

def main() -> None:
    print(f"cryptography {cryptography.__version__}")

# The square. A 1024-bit prime with its top two bits set, squared, is # exactly 2048 bits -- the same size a working generator would produce.
    random.seed(7)
    p = next_prime((0b11 << 1022) | random.getrandbits(1000))
    square = p * p
    assert square.bit_length() == 2048

    # The control. Two primes just above sqrt(2**2047), so the product is
# exactly 2048 bits and the gap is a few hundred -- the shape a generator # makes when it takes the next prime after the first.
    random.seed(46)
    root = math.isqrt(1 << 2047) + 1
    a = next_prime(root + random.getrandbits(1000))
    b = next_prime(a + 1)
    close = a * b
    assert close.bit_length() == 2048

    for modulus, name, cn, serial in (
        (square, "positive/ZT-041-modulus-is-a-square.pem", "square.example.com", 12345),
        (close, "negative/ZT-041-control-close-primes.pem", "close.example.com", 12346),
    ):
        (HERE / name).write_bytes(certificate(modulus, cn, serial))
        print(f"wrote {name}  modulus {modulus.bit_length()} bits")
    print(f"control gap q - p = {b - a}")

if __name__ == "__main__":
    main()
