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
- zlint exits with a non-zero code when it reports `error` results; that is expected and not a failure of this tool.
- The certificate samples from the parent project live under `../zlint/<group>/<entry>/positive/`.
