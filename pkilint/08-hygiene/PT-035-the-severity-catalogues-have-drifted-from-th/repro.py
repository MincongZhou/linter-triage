#!/usr/bin/env python3
"""another entry here reproduction: pkilint's shipped finding_metadata.csv against the
live validator enumeration.

Self-contained: needs only pkilint installed (0.13.3 as measured).

    ~/.venv/linters/bin/python ./repro.sh

Prints, per profile, the CSV row count, the live count, and the three kinds of
disagreement. A tool whose shipped catalogue matched its code would print
0/0/0 on every line.
"""
import csv import pathlib import sys

from pkilint import report from pkilint.pkix import certificate from
pkilint.cabf import serverauth, smime from pkilint.cabf.serverauth import
serverauth_constants from pkilint.cabf.smime import smime_constants from
pkilint import etsi from pkilint.etsi import etsi_constants import pkilint

SRC = pathlib.Path(pkilint.__file__).parent

def serverauth_types():
    return list(serverauth_constants.CertificateType)

def serverauth_build(t):
    return certificate.create_pkix_certificate_validator_container(
        serverauth.create_decoding_validators(), serverauth.create_validators(t)
    )

def smime_types():
    return [(v, g) for g in smime_constants.Generation
            for v in smime_constants.ValidationLevel]

def smime_build(t):
    level, generation = t
    return certificate.create_pkix_certificate_validator_container(
        smime.create_decoding_validators(),
        smime.create_subscriber_validators(level, generation),
    )

def etsi_types():
    return list(etsi_constants.CertificateType)

def etsi_build(t):
    return certificate.create_pkix_certificate_validator_container(
        etsi.create_decoding_validators(t), etsi.create_validators(t)
    )

PROFILES = {
    "serverauth": (serverauth_types, serverauth_build,
                   SRC / "cabf/serverauth/finding_metadata.csv"),
    "smime": (smime_types, smime_build, SRC / "cabf/smime/finding_metadata.csv"),
    "etsi": (etsi_types, etsi_build, SRC / "etsi/finding_metadata.csv"),
}

def main():
    import importlib.metadata as md
    print(f"pkilint {md.version('pkilint')} at {SRC}")
    for name, (types, build, csv_path) in PROFILES.items():
        live = set()
        for t in types():
            for v in report.get_included_validations(build(t)):
                live.add((v.severity.name, v.code))
        shipped = set()
        if csv_path.is_file():
            with csv_path.open(encoding="utf-8", newline="") as fh:
                shipped = {(r["severity"], r["code"]) for r in csv.DictReader(fh)}
        lc = {c for _, c in live}
        sc = {c for _, c in shipped}
        sev_live = {c: s for s, c in live}
        sev_ship = {c: s for s, c in shipped}
        disagree = sorted(c for c in lc & sc if sev_live[c] != sev_ship[c])
        print(f"\n{name}: csv rows {len(sc)}, live validations {len(lc)}")
        print(f"  in the csv, no longer performed : {len(sc - lc)}")
        print(f"  performed, absent from the csv  : {len(lc - sc)}")
        print(f"  severity disagreements          : {len(disagree)}")
        for c in sorted(sc - lc):
            print(f"    STALE       {sev_ship[c]:<8}{c}")
        for c in disagree:
            print(f"    SEVERITY    {c}  csv={sev_ship[c]} live={sev_live[c]}")
        for c in sorted(lc - sc):
            print(f"    MISSING     {sev_live[c]:<8}{c}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
