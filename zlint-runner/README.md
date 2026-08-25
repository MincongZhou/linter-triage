# zlint-runner

[![中文](https://img.shields.io/badge/中文-readme-blue)](README.zh.md) · [English](README.md)

An interactive helper for running [zlint](https://github.com/zmap/zlint) against a certificate and saving the output.

## What's inside

```
zlint-runner/
├── run_zlint.py      # interactive script (source)
├── run_zlint.bat     # double-click launcher (requires Python)
├── build.bat         # one-click repackage via PyInstaller
├── dist/
│   └── run_zlint.exe # standalone executable (Python bundled, no install needed)
├── build/            # PyInstaller intermediate output (git-ignored)
└── run_zlint.spec    # PyInstaller spec file
```

## Usage

### Option A — standalone exe (no Python needed)

1. Share/keep `dist/run_zlint.exe` on the target machine.
2. Double-click it (or run from a terminal).
3. When prompted, enter:
   - the path to your `zlint` executable (e.g. `C:\...\zlint.exe`),
   - the path to the certificate to check (e.g. `cert.pem`),
   - optionally a single lint name (`-includeNames`); leave blank for all.
4. Results print to screen and are saved as `<cert>.zlint.json`. If the output is JSON, a `<cert>.zlint.summary.json` with only `error`/`warn`/`fatal` entries is also written.

### Batch mode — scan every certificate in a folder

No interaction needed; just point at a folder and it recursively scans all certificates (`.pem`/`.der`/`.crt`/`.cer`):

```powershell
# Batch-run zlint over every cert in a folder
python run_zlint.py --dir "path/to/cert-folder" --zlint "path/to/zlint.exe"

# Or from the bundled standalone exe (no Python needed)
run_zlint.exe --dir "path/to/cert-folder" --zlint "path/to/zlint.exe"
```

Optional arguments:
- `--pattern`: match a specific glob, e.g. only the project's positive samples:
  ```powershell
  python run_zlint.py --dir "zlint" --pattern "*/positive/*.pem" --zlint "zlint.exe"
  ```
- `--include`: run only one lint name (same as `-includeNames`).

Batch-mode behavior:
- Each certificate is saved as `<cert>.zlint.json` and `<cert>.zlint.summary.json` (error/warn/fatal only).
- An extra `<folder-name>.batch.summary.json` is written in the folder, summarizing hits across all certificates, and the count of hit certificates and total checks is printed.

### Option B — run from source (needs Python)

```powershell
python run_zlint.py
```
or double-click `run_zlint.bat`.

### Repackage

```powershell
pyinstaller --onefile --console --name run_zlint run_zlint.py
```
or double-click `build.bat`. The output lands in `dist/run_zlint.exe`.

## Notes

- This tool does **not** include zlint itself. You must supply your own `zlint` executable.
- The `zlint.exe` bundled in the parent repository root is **version 3.6.8** — the last zlint release that still ships a Windows binary. Newer versions dropped Windows (and FreeBSD) release targets, so no prebuilt `zlint.exe` exists for the pinned `v3.7.1-20-g1007b1d5`; on Windows you must build newer zlint from source or use 3.6.8.
- zlint exits with a non-zero code when it reports `error` results; that is expected and not a failure of this tool.
- The certificate samples from the parent project live under `../zlint/<group>/<entry>/positive/`.
