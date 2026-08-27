# zlint-runner

[![中文](https://img.shields.io/badge/中文-readme-blue)](README.zh.md) · [English](README.md)

An interactive helper for running [zlint](https://github.com/zmap/zlint) against a certificate and saving the output.

## What's inside

```
zlint-runner/
├── run_zlint.py           # interactive script (source)
├── run_zlint.bat          # double-click launcher (requires Python)
├── build.bat              # one-click repackage via PyInstaller
├── dist/
│   ├── run_zlint.exe      # standalone executable (Python bundled, no install needed)
│   └── audit_coverage.exe # audit coverage table (source lives at ../audit_coverage.py)
├── build/                 # PyInstaller intermediate output (git-ignored)
├── run_zlint.spec         # PyInstaller spec for run_zlint
└── audit_coverage.spec    # PyInstaller spec for audit_coverage
```

## Usage

### Option A — standalone exe (no Python needed)

1. Share/keep `dist/run_zlint.exe` on the target machine.
2. Double-click it (or run from a terminal).
3. When prompted, enter:
   - the path to your `zlint` executable (e.g. `C:\...\zlint.exe`),
   - **whether to batch-scan a folder** (`y`) or check a single certificate (`n`/`Enter`):
     - choose `y` → enter the **folder** to recursively scan (`.pem`/`.der`/`.crt`/`.cer`),
     - choose `n` → enter the **single certificate file** to check (e.g. `cert.pem`),
   - optionally a single lint name (`-includeNames`); leave blank for all.
4. Results print to screen and are saved as `<cert>.zlint.json`. If the output is JSON, a `<cert>.zlint.summary.json` with only `error`/`warn`/`fatal` entries is also written. In batch mode, an extra `<folder-name>.batch.summary.json` summarizes hits across all certificates.
5. At the end it prints `按回车退出...` ("press Enter to exit") and the window stays open (even when double-clicked), so you can read the results.

### Batch mode — scan every certificate in a folder

No interaction needed; just point at a folder and it recursively scans all certificates (`.pem`/`.der`/`.crt`/`.cer`):

```powershell
# Batch-run zlint over every cert in a folder
python run_zlint.py --dir "path/to/cert-folder" --zlint "path/to/zlint.exe"

# Or from the bundled standalone exe (no Python needed)
run_zlint.exe --dir "path/to/cert-folder" --zlint "path/to/zlint.exe"
```

You can also target a single certificate directly without interaction:

```powershell
python run_zlint.py --cert "path/to/cert.pem" --zlint "path/to/zlint.exe"
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

### Audit coverage table (`audit_coverage`)

The root [`../audit_coverage.py`](../audit_coverage.py) (or `dist/audit_coverage.exe`) produces an audit-ready matrix Excel: **rows = every lint rule** (the 432-rule catalog ∪ zlint's actual lints), **columns = each certificate**, each cell = that rule's disposition for that cert (`pass`/`error`/`warn`/`NA`/`NE`/`info`; `不适用(guard未过)` for rules whose precondition fails; `版本无此规则` for catalog names missing from this zlint version). See [../USAGE.md](../USAGE.md) → *Audit coverage* for details and background.

```powershell
# one matrix (each cert = a column)
dist\audit_coverage.exe --zlint zlint.exe --cert cert.pem --out coverage.xlsx
dist\audit_coverage.exe --zlint zlint.exe --dir ..\testdata --pattern "*aia*.pem" --out matrix.xlsx

# batch: one table per cert into a folder
dist\audit_coverage.exe --zlint zlint.exe --dir ..\testdata --pattern "*aia*.pem" --out-dir out\
```

### Repackage

Double-click `build.bat` — it rebuilds both `dist/run_zlint.exe` and `dist/audit_coverage.exe`. Individually:

```powershell
pyinstaller --onefile --console --name run_zlint run_zlint.py
pyinstaller audit_coverage.spec --noconfirm
```

## Notes

- This tool does **not** include zlint itself. You must supply your own `zlint` executable.
- The `zlint.exe` bundled in the parent repository root is **version 3.6.8** — the last zlint release that still ships a prebuilt Windows binary. Newer versions dropped Windows (and FreeBSD) release targets, so on Windows either keep using 3.6.8 or build a newer version from source.
- zlint exits with a non-zero code when it reports `error` results; that is expected and not a failure of this tool.
- The certificate samples from the parent project live under `../zlint/<group>/<entry>/positive/`.
- To inspect a certificate's internals (subject, extensions, whether `certificatePolicies` is empty, etc.), use the parent's [`../decode_cert.py`](../decode_cert.py): `python ../decode_cert.py cert.pem`.
