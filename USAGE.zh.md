# 项目运行指南（中文）

本文详细介绍 **linter-triage** 这个项目该怎么跑：用自带证书样本，对照四个证书合规检查工具（zlint / pkilint / x509lint / certlint）复现 193 个已确认缺陷。

- [English](USAGE.md)
- 返回：[中文总览](README.zh.md)

---

## 0. 先搞清楚两件事

**这个仓库是什么**：它是缺陷的"证据库"。每条缺陷 = 一份证书样本 + 一个 `repro.sh` 复现脚本。脚本把证书喂给你本地安装的 linter 二进制，对比"工具实际输出"与"正确输出"。

**版本要注意**：仓库里每条缺陷都对照一个**固定版本**复现过（见总览表的 `pinned at` 列）。你本地用的版本若不同，部分缺陷可能"不复现"——这本身也是结论，不代表脚本错了。

> 本仓库根目录附带的 `zlint.exe` 是 **3.6.8**，这是 zlint 最后一个仍提供 Windows 二进制的发布版本；更新版本已取消 Windows/FreeBSD 发布目标，钉住的 `v3.7.1-20-g1007b1d5` 没有预编译 exe。Windows 上要么用 3.6.8，要么自行从源码编译。

---

## 1. 准备四个 linter 二进制

你需要自己准备好这些可执行文件（本仓库只带复现材料，不带 linter 本身）：

| 工具 | 固定版本 | 二进制名（示例） |
|---|---|---|
| zlint | `v3.7.1-20-g1007b1d5` | `zlint` / `zlint.exe` |
| pkilint | `0.13.3` | `pkilint` |
| x509lint | `103c92f` | `x509lint` |
| certlint | `528d78e` | `certlint` |

每个 `repro.sh` 的**第一个参数**就是该工具二进制路径，缺省默认叫 `zlint` / `pkilint` 等（需在 PATH 里）。本文以 `zlint.exe` 为例。

---

## 2. 运行环境

`repro.sh` / `run-all.sh` 是 **bash 脚本**，需要：

- **Git Bash**（Windows 装 Git for Windows 时自带，开始菜单搜 "Git Bash"），或
- **WSL**（Windows Subsystem for Linux），或
- 任意带 bash 的 Unix/macOS 终端。

> 纯 PowerShell / cmd 不能直接跑 `.sh`。不过 `zlint.exe` 本身能在 PowerShell 里直接调用（见第 5 节）。

Git for Windows 装好后，`bash.exe` 通常在：
`C:\Users\<你>\AppData\Local\Programs\Git\bin\bash.exe`
即使它不在 PATH 里，也能用这个完整路径直接调。

---

## 3. 跑单个缺陷（最常用，推荐先看一两条）

进到具体条目目录，执行它的脚本，传入你的二进制路径：

```bash
# 验证 zlint 的某个缺陷
zlint/04-predicate/ZT-034-e_sub_cert_cert_policy_empty/repro.sh "/c/Users/.../zlint.exe"
```

脚本会拿证书跑 linter，然后打印「observed（实际）」与「correct（正确应是）」。例如 ZT-034 会显示 `observed: pass` / `correct: error`——说明工具本该报错却放行了（缺陷复现）。

若你装的是固定版本，复现应一致；若用的是更老/更新的版本，可能输出不同或"不复现"。

---

## 4. 跑单个工具的全部复现

每个工具目录都有自己的 `run-all.sh`，参数是该工具的二进制路径：

```bash
bash zlint/run-all.sh    "/c/Users/.../zlint.exe"
bash pkilint/run-all.sh  "/c/Users/.../pkilint"
bash x509lint/run-all.sh "/c/Users/.../x509lint"
bash certlint/run-all.sh "/c/Users/.../certlint"
```

`run-all.sh` 会遍历该工具下所有 `repro.sh`（带脚本的条目），逐个执行并打印结果。建议重定向到文件便于查看：

```bash
bash zlint/run-all.sh "/c/Users/.../zlint.exe" 2>&1 | tee zlint-run.log
```

### 更易读的输出（推荐）：`run-readable.sh`

原 `run-all.sh` 的 zlint 结果是**一行压扁的 JSON**，混在说明文字里不好读。仓库根目录的 `run-readable.sh` 是它的包装器，做两件事：

1. 把全部输出落盘到 `zlint-readable.log`（原始完整内容）；
2. 另外生成 `zlint-readable.pretty.log`——把其中压扁的 JSON 用 `jq`（优先）或 `python`（自动探测）**美化展开**，每条证书的 lint 结果缩进清晰。

```bash
bash run-readable.sh "/c/Users/.../zlint.exe"
```

跑完用编辑器打开上面两个文件即可。JSON 美化依赖 `jq` 或 `python`：Git Bash 默认不带 `jq`，脚本会自动退回用 Python（探测 `python`/`py` 及常见安装路径）；若两者都没有，则保留原始压扁 JSON。

---

## 5. 一次性跑全部四个工具

根目录的 `run-all.sh` 接受四个二进制路径（顺序：zlint、pkilint、x509lint、certlint）：

```bash
bash run-all.sh \
  "/c/Users/.../zlint.exe" \
  "/c/Users/.../pkilint" \
  "/c/Users/.../x509lint" \
  "/c/Users/.../certlint"
```

没传的二进制会被自动跳过（输出 `skipping xxx (no binary given)`）。

---

## 6. 只用 zlint + 证书（不跑复现项目）

如果你只是想用 `zlint.exe` 检查某个证书（不一定来自本项目），直接在 PowerShell 里：

```powershell
& "c:/.../zlint.exe" "c:/.../某个证书.pem"
```

项目里自带的样本证书都在 `zlint/<组>/<条目>/positive/`（和少数 `negative/`）下，共 121 个 `.pem`，可以直接喂给它：

```bash
# Git Bash 里批量跑所有 positive 样本
for f in zlint/*/*/positive/*.pem; do
  echo "==== $f"
  "/c/Users/.../zlint.exe" "$f"
done
```

只看 `error`/`warn`/`fatal`：
```bash
"/c/Users/.../zlint.exe" -includeNames=e_sub_cert_cert_policy_empty 证书.pem
```

也可以用本仓库提供的 `zlint-runner/run_zlint.exe`（自带 Python、双击即用、交互式填路径），详见 [zlint-runner/README.zh.md](zlint-runner/README.zh.md)。

### 使用 `run_zlint` 辅助工具

`zlint-runner/run_zlint.py`（或打包好的 `run_zlint.exe`）把上面的命令封装起来，额外支持保存结果和批量模式。有三种用法：

**交互式（双击 `run_zlint.exe`，或 `python run_zlint.py`）**——按提示输入：
1. `zlint` 可执行文件路径（如 `zlint.exe`），
2. 填 `y` 批量扫描文件夹，或填 `n`/回车只检查单张证书，再输入文件夹 / 证书路径，
3. 可选填 lint 名（`-includeNames`），留空表示全部。

**单张证书，无需交互：**

```powershell
# 从源码运行（需 Python）
python zlint-runner/run_zlint.py --cert "c:/.../某个证书.pem" --zlint "c:/.../zlint.exe"

# 从打包好的 exe 运行（无需 Python）
zlint-runner/run_zlint.exe --cert "c:/.../某个证书.pem" --zlint "c:/.../zlint.exe"
```

**批量扫描整个文件夹（递归，`.pem`/`.der`/`.crt`/`.cer`）：**

```powershell
python zlint-runner/run_zlint.py --dir "zlint" --zlint "zlint.exe" --pattern "*/positive/*.pem"
```

每张证书会保存为 `<证书>.zlint.json`（另有 `<证书>.zlint.summary.json` 只含 `error`/`warn`/`fatal`）。批量模式还会在文件夹下额外生成 `<文件夹>.batch.summary.json` 汇总所有命中。完整说明见 [zlint-runner/README.zh.md](zlint-runner/README.zh.md)。

### 解码证书（PEM/DER → 可读内容）

`decode_cert.py` 用来查看证书内部到底有什么字段——当某个 `repro.sh` 的论断依赖特定字段时（例如空的 `certificatePolicies`）特别有用。它同时支持 PEM 和 DER，并自动识别。

```powershell
# 单张证书
python decode_cert.py "c:/.../某个证书.pem"

# 批量：递归解码文件夹下的所有证书
python decode_cert.py "zlint"

# 从 stdin 管道传入 PEM
type cert.pem | python decode_cert.py -
```

输出包含主题/签发者、序列号、有效期、签名算法、公钥（算法/位数），以及每个扩展及其 `critical` 标记（如 `certificatePolicies`、SAN、KeyUsage）。依赖 `pip install cryptography`。在 Windows 上脚本会强制控制台使用 UTF-8，因此含非 ASCII 字符的主题也能正常显示。

---

## 7. 包内自检（不需要任何 linter）

`check.sh` 验证这份材料自身是否完整一致（编号连续、目录/README/脚本齐全）：

```bash
bash check.sh
```

输出 `no problems` 表示自洽，否则列出问题项。

---

## 8. 怎么读懂一个条目

每个缺陷目录结构一致：

- `README.md` —— 缺陷说明、引用哪条规范、为什么是 bug
- `positive/` —— 触发缺陷的证书（`NONE.md` 表示输入是脚本现造的，或讨论的是永远执行不到的源码）
- `negative/`（若有）—— 对照组证书：只差一个字段、工具能正确处理。一对用例才能证明机制
- `repro.sh` —— 复现脚本（manifest 里 `repro=yes` 才有；其余是读源码+手跑确认的）

想查有哪些条目，看各工具目录的 `MANIFEST.tsv`（列：编号、分组、linter 内部检查名、严重度、是否有脚本、positive/negative 数量、目录路径）。

---

## 9. 典型使用场景

1. **评估要不要信任/部署某个 linter**：按严重度（manifest 的 `severity` 列）挑 High 条目跑一遍。
2. **确认某 bug 在你用的版本还存在否**：跑对应 `repro.sh`，看是否还复现。
3. **向上游报 bug / 验证修复**：复现脚本就是最小可重跑的用例。
4. **了解规范盲区**：读 `MISSING-LINTS.zh.md`，看哪些合规要求四个工具全都没覆盖。

---

## 10. 常见问题

**Q：为什么有些条目没有 `repro.sh`？**
A：MANIFEST 里 `repro=no` 的 19 条（zlint）是通过读固定版本源码 + 手工运行确认的，比如"不可达代码"靠读代码定论，打包演示脚本无意义。

**Q：用 3.6.8 跑项目复现会有问题吗？**
A：不会"出错"，但部分缺陷可能不复现（3.6.8→3.7.1 之间有 33 个 commit，可能已修掉某些 bug）。这本身是有效结论。要精确复现，应使用钉住的版本。

**Q：PowerShell 能直接跑 .sh 吗？**
A：不能。但可以用 Git 自带的 bash 调用：`& "C:\...\Git\bin\bash.exe" -c "cd '/c/...' && bash zlint/run-all.sh '/c/.../zlint.exe'"`。或直接用 Git Bash 终端。
