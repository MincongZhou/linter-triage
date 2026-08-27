# How to run this project

A detailed guide to running linter-triage: reproducing the 193 confirmed defects against the four certificate linters (zlint / pkilint / x509lint / certlint) using the bundled certificate samples.

- [中文](USAGE.zh.md)
- Back to: [English overview](README.md)

---

## 0. Two things to know first

**What this repo is**: an evidence library for defects. Each defect = a certificate sample + a `repro.sh` script that feeds the cert to your locally installed linter binary and compares the tool's actual output with the correct output.

**Watch the version**: every defect was reproduced against a pinned version (see the `pinned at` column in the overview). If your local version differs, some defects may not reproduce — that is itself a finding, not a broken script.

> The `zlint.exe` bundled in this repo root is **version 3.6.8** — the last zlint release that still ships a Windows binary. Newer versions dropped Windows (and FreeBSD) release targets, so no prebuilt `zlint.exe` exists for the pinned `v3.7.1-20-g1007b1d5`. On Windows you must build newer zlint from source or use 3.6.8.

---

## 1. Prepare the four linter binaries

You must provide these executables yourself (this repo only ships reproduction material, not the linters):

| tool | pinned at | binary (example) |
|---|---|---|
| zlint | `v3.7.1-20-g1007b1d5` | `zlint` / `zlint.exe` |
| pkilint | `0.13.3` | `pkilint` |
| x509lint | `103c92f` | `x509lint` |
| certlint | `528d78e` | `certlint` |

The first argument of each `repro.sh` is the binary path; if omitted it defaults to `zlint` / `pkilint` etc. (must be on PATH). This guide uses `zlint.exe` as the example.

---

## 2. Runtime

`repro.sh` / `run-all.sh` are **bash scripts**, requiring:

- **Git Bash** (ships with Git for Windows; search "Git Bash" in Start menu), or
- **WSL**, or
- any Unix/macOS terminal with bash.

> Plain PowerShell / cmd cannot run `.sh` directly. However `zlint.exe` itself runs fine in PowerShell (see section 5).

After installing Git for Windows, `bash.exe` is typically at `C:\Users\<you>\AppData\Local\Programs\Git\bin\bash.exe` — even if not on PATH, you can call it by that full path.

---

## 3. Run a single defect (most common)

Go into the entry directory and run its script with your binary path:

```bash
zlint/04-predicate/ZT-034-e_sub_cert_cert_policy_empty/repro.sh "/c/Users/.../zlint.exe"
```

The script runs the linter on the cert and prints `observed` vs `correct`. For ZT-034 it shows `observed: pass` / `correct: error` — the tool should have errored but passed (defect reproduced).

If you use the pinned version, reproduction should match. With a different version, output may differ or not reproduce.

---

## 4. Run all reproductions for one tool

Each tool directory has its own `run-all.sh`, taking that tool's binary path:

```bash
bash zlint/run-all.sh    "/c/Users/.../zlint.exe"
bash pkilint/run-all.sh  "/c/Users/.../pkilint"
bash x509lint/run-all.sh "/c/Users/.../x509lint"
bash certlint/run-all.sh "/c/Users/.../certlint"
```

`run-all.sh` iterates every `repro.sh` under that tool and prints results. Redirect to a file:

```bash
bash zlint/run-all.sh "/c/Users/.../zlint.exe" 2>&1 | tee zlint-run.log
```

### More readable output (recommended): `run-readable.sh`

The raw `run-all.sh` prints zlint results as **one-line compressed JSON** mixed with explanatory text, which is hard to read. The root `run-readable.sh` wraps it and does two things:

1. Dumps the full output to `zlint-readable.log` (raw, complete).
2. Additionally produces `zlint-readable.pretty.log` — where the compressed JSON is **pretty-printed** (indented) using `jq` (preferred) or `python` (auto-detected), so each certificate's lint results are clear.

```bash
bash run-readable.sh "/c/Users/.../zlint.exe"
```

Open those two files in an editor afterwards. JSON pretty-printing needs `jq` or `python`: Git Bash does not ship `jq` by default, so the script falls back to Python (detecting `python`/`py` and common install paths); if neither exists, the raw compressed JSON is kept.

---

## 5. Run all four tools at once

The root `run-all.sh` takes four binary paths (order: zlint, pkilint, x509lint, certlint):

```bash
bash run-all.sh \
  "/c/Users/.../zlint.exe" \
  "/c/Users/.../pkilint" \
  "/c/Users/.../x509lint" \
  "/c/Users/.../certlint"
```

Any binary not passed is skipped (`skipping xxx (no binary given)`).

---

## 6. Just zlint + a certificate (not the reproduction project)

`zlint` is the open-source linter this project studies: <https://github.com/zmap/zlint>

To use `zlint.exe` on a cert (not necessarily from this repo), in PowerShell:

```powershell
& "c:/.../zlint.exe" "c:/.../some-cert.pem"
```

The bundled samples live under `zlint/<group>/<entry>/positive/` (and a few `negative/`), 121 `.pem` files total:

```bash
# In Git Bash, run all positive samples
for f in zlint/*/*/positive/*.pem; do
  echo "==== $f"
  "/c/Users/.../zlint.exe" "$f"
done
```

To see only `error`/`warn`/`fatal`:
```bash
"/c/Users/.../zlint.exe" -includeNames=e_sub_cert_cert_policy_empty cert.pem
```

You can also use the bundled `zlint-runner/run_zlint.exe` (Python bundled, double-click, interactive). See [zlint-runner/README.md](zlint-runner/README.md).

### Using the `run_zlint` helper

`zlint-runner/run_zlint.py` (or its bundled `run_zlint.exe`) wraps the commands above with saved output and a batch mode. It works three ways:

**Interactive (double-click `run_zlint.exe`, or `python run_zlint.py`)** — answer the prompts:
1. path to your `zlint` binary (e.g. `zlint.exe`),
2. `y` to batch-scan a folder, or `n`/`Enter` to check a single cert, then the folder / cert path,
3. optional lint name (`-includeNames`); blank = all.

**Single certificate, no prompts:**

```powershell
# From source (needs Python)
python zlint-runner/run_zlint.py --cert "c:/.../some-cert.pem" --zlint "c:/.../zlint.exe"

# From the bundled exe (no Python)
zlint-runner/run_zlint.exe --cert "c:/.../some-cert.pem" --zlint "c:/.../zlint.exe"
```

**Batch-scan a whole folder (recursive, `.pem`/`.der`/`.crt`/`.cer`):**

```powershell
python zlint-runner/run_zlint.py --dir "zlint" --zlint "zlint.exe" --pattern "*/positive/*.pem"
```

Each certificate is saved as `<cert>.zlint.json` (+ `<cert>.zlint.summary.json` with only `error`/`warn`/`fatal`). Batch mode additionally writes `<folder>.batch.summary.json` summarizing all hits. Full reference: [zlint-runner/README.md](zlint-runner/README.md).

**Why does a cert's Excel/JSON show fewer lints than the full rule set?**

The rule inventory (`zlint-lint规则详解.xlsx`, 432 lints) is the **catalog** — how many checks zlint *knows about*. When zlint runs on a single cert it only *executes* the lints whose precondition (guard / `CheckApplies`) is satisfied by that cert; lints that don't apply are skipped and **never appear in the output**. So a per-cert result count lower than 432 is normal — it is simply the number of lints that cert triggers. `run_zlint.py` filters nothing; every row in the Excel is real zlint output.

Common reasons a lint is skipped for a given cert:

- cert type mismatch (leaf-only vs CA-only rules, etc.)
- required extension/field absent (SCT, OCSP, AIA, CDP, ...)
- specialized profiles (S/MIME, EV, code signing, ETSI, browser-specific policy)
- version-specific rules (v2-only fields, pre-2014 certs, ...)

Example: `testdata/arpa_sub0_rev4x_rev6x_effx.pem` outputs 382 lints (381 of them are inside the 432-lint catalog; the other 51 catalog lints are not applicable to this cert). Also note the catalog does not cover every zlint lint (zlint has 800+); for lints outside the catalog the Excel falls back to a keyword-based description.

**Audit coverage: prove every rule has a conclusion**

To turn the explanation above into an audit-ready artifact, run `audit_coverage.py`. It builds a matrix Excel — **rows = every rule** (the 432-lint catalog ∪ zlint's actual lints), **columns = each certificate** — so every rule has an explicit disposition:

```powershell
# single cert
python audit_coverage.py --zlint zlint.exe --cert cert.pem --out coverage.xlsx

# multiple certs in one matrix (each cert = one column)
python audit_coverage.py --zlint zlint.exe --cert cert1.pem cert2.pem cert3.pem --out coverage.xlsx

# a whole folder (recursive) in one matrix
python audit_coverage.py --zlint zlint.exe --dir zlint --pattern "*/positive/*.pem" --out coverage.xlsx

# batch: ONE table per cert, written to a folder (recommended for many certs)
python audit_coverage.py --zlint zlint.exe --dir testdata --pattern "*aia*.pem" --out-dir out/
#   → out/<cert-name>.audit.xlsx for every matched cert
```

No Python? Use the bundled exe (same arguments):

```powershell
zlint-runner/dist/audit_coverage.exe --zlint zlint.exe --cert cert.pem --out coverage.xlsx
zlint-runner/dist/audit_coverage.exe --zlint zlint.exe --dir testdata --pattern "*aia*.pem" --out-dir out/
```

Cell values:

- `pass` / `error` / `warn` / `NA` / `NE` / `info` — zlint's actual verdict for that rule
- `不适用(guard未过)` — the lint exists in this zlint, but the cert fails its precondition (`CheckApplies`), so zlint never executes it (even `-includeNames` will not force it)
- `版本无此规则` — the name exists only in the catalog, not in this zlint version
- a row present only in zlint is labeled `清单未收录`

The trailing summary rows give per-cert counts (executed / pass / problems / warnings / not-applicable / version-missing / total). A report can then state, e.g.: *"433 rules considered; 382 executed (0 error, 0 warn); 18 not applicable (guard); 33 not present in zlint 3.6.8; 0 unaccounted."* Requires Python with `openpyxl` (same as `run_zlint.py`).

### Decode a certificate (PEM/DER → human-readable)

`decode_cert.py` shows what is actually inside a certificate — useful when a `repro.sh` claim depends on a specific field (e.g. an empty `certificatePolicies`). It works on PEM **or** DER and auto-detects.

```powershell
# Single certificate
python decode_cert.py "c:/.../some-cert.pem"

# Batch: recursively decode every cert in a folder
python decode_cert.py "zlint"

# Pipe a PEM from stdin
type cert.pem | python decode_cert.py -
```

Output includes Subject/Issuer, serial, validity, signature algorithm, public key (algorithm/size), and every extension with its `critical` flag (e.g. `certificatePolicies`, SAN, KeyUsage). Requires `pip install cryptography`. On Windows the console is forced to UTF-8 so non-ASCII subjects print correctly.

### Which certificates are "problematic"? (positive vs negative)

The bugs collected here are **bugs in the linter (zlint/pkilint/...)**, not certificates failing a check. Each defect directory uses two subfolders to mark intent:

- `positive/` — certificates that **should be flagged** by that lint (constructed to be non-compliant w.r.t. that rule). These are the "problematic" certificates.
- `negative/` — certificates that **should NOT be flagged** (valid / compliant). These are the "clean"对照 certificates, proving the lint does not wrongly reject good certs.

So within this repo: `positive/` = problematic, `negative/` = fine.

**For your own certificate**, the project does not auto-classify it. To judge it:

1. Run zlint on the whole cert and look for `error` / `warn`:
   ```powershell
   zlint.exe "your-cert.pem"
   # or via the helper (also writes *.zlint.summary.json with only error/warn/fatal)
   zlint-runner/run_zlint.exe --cert "your-cert.pem" --zlint "zlint.exe"
   ```
   - `result: "error"` for a lint → that check considers the cert problematic
   - all `pass` / `NA` → by zlint's reading, the cert is fine
   - `warn` → a non-fatal warning worth noting
2. Inspect fields with `decode_cert.py` to see exactly which extension/field is off:
   ```powershell
   python decode_cert.py "your-cert.pem"
   ```
3. To match against a known defect, take the `error`/`warn` lint names from zlint's output and look them up in the per-defect `README.md` files under `zlint/*/*/`.

---

## 7. Self-check (no linter needed)

`check.sh` verifies the material is internally consistent (continuous numbering, required dirs/READMEs/scripts present):

```bash
bash check.sh
```

`no problems` means consistent; otherwise it lists issues.

---

## 8. Reading an entry

Each defect directory:

- `README.md` — explanation, which spec clause, why it's a bug
- `positive/` — the cert that triggers the defect (`NONE.md` means input is constructed on the fly, or the entry discusses unreachable source)
- `negative/` (if present) — control cert: differs by one field, handled correctly. A pair proves the mechanism
- `repro.sh` — reproduction script (only when manifest `repro=yes`; others confirmed by reading source + manual runs)

List entries via each tool's `MANIFEST.tsv` (columns: id, group, internal lint name, severity, has script, positive/negative counts, directory).

---

## 9. Typical use cases

1. **Evaluate trusting/deploying a linter**: pick High-severity entries (manifest `severity`) and run them.
2. **Confirm a bug exists in your version**: run the `repro.sh`, see if it still reproduces.
3. **File an upstream bug / verify a fix**: the repro script is a minimal rerunnable case.
4. **Learn the spec blind spots**: read `MISSING-LINTS.md`.

---

## 10. FAQ

**Q: Why do some entries lack `repro.sh`?**
A: In the manifest, `repro=no` entries (19 for zlint) were confirmed by reading the pinned source + manual runs; e.g. "unreachable code" is settled by reading code, so a demo script is pointless.

**Q: Any problem using 3.6.8 for the project reproductions?**
A: No error, but some defects may not reproduce (33 commits between 3.6.8 and 3.7.1 may have fixed them). That is a valid finding. For exact reproduction, use the pinned version.

**Q: Can PowerShell run .sh directly?**
A: No. But you can call Git's bash: `& "C:\...\Git\bin\bash.exe" -c "cd '/c/...' && bash zlint/run-all.sh '/c/.../zlint.exe'"`. Or just use the Git Bash terminal.
