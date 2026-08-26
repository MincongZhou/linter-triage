# zlint-runner

[![English](https://img.shields.io/badge/English-readme-blue)](README.md) · [中文](README.zh.md)

一个交互式小工具：调用 [zlint](https://github.com/zmap/zlint) 检查证书，并把结果保存下来。

## 目录内容

```
zlint-runner/
├── run_zlint.py      # 交互式脚本（源码）
├── run_zlint.bat     # 双击启动器（需安装 Python）
├── build.bat         # 用 PyInstaller 一键重新打包
├── dist/
│   └── run_zlint.exe # 独立可执行文件（已内置 Python，无需安装）
├── build/            # PyInstaller 中间产物（已被 git 忽略）
└── run_zlint.spec    # PyInstaller 规格文件
```

## 使用方法

### 方式一 —— 独立 exe（无需 Python）

1. 把 `dist/run_zlint.exe` 放到目标机器上。
2. 双击运行（或在终端里运行）。
3. 按提示输入：
   - `zlint` 可执行文件的路径（如 `C:\...\zlint.exe`），
   - **是否批量扫描一个文件夹**（`y`）还是只检查单个证书（`n`/回车）：
     - 选 `y` → 输入要递归扫描的**文件夹**（内含 `.pem`/`.der`/`.crt`/`.cer`），
     - 选 `n` → 输入要检查的**单个证书文件**（如 `cert.pem`），
   - 可选填单个 lint 名（`-includeNames`），留空表示全部。
4. 结果会打印到屏幕，并保存为 `<证书>.zlint.json`。若输出为 JSON，还会额外生成一份只含 `error`/`warn`/`fatal` 的 `<证书>.zlint.summary.json`。批量模式下，还会在文件夹下额外生成 `<文件夹名>.batch.summary.json`，汇总所有证书的命中结果。
5. 运行结束后会显示 `按回车退出...`，窗口不会自动关闭（双击 exe 也不会秒关），方便你查看结果。

### 批量模式 —— 遍历一个文件夹里的所有证书

无需交互，直接指定文件夹即可递归遍历其中所有证书（`.pem`/`.der`/`.crt`/`.cer`）：

```powershell
# 批量为某个文件夹下的所有证书运行 zlint
python run_zlint.py --dir "路径/到/证书文件夹" --zlint "路径/到/zlint.exe"

# 或从已打包的 exe（独立版无需 Python）
run_zlint.exe --dir "路径/到/证书文件夹" --zlint "路径/到/zlint.exe"
```

也可以不交互地直接指定单个证书：

```powershell
python run_zlint.py --cert "路径/到/cert.pem" --zlint "路径/到/zlint.exe"
```

可选参数：
- `--pattern`：只匹配特定 glob，例如只跑项目的 positive 样本：
  ```powershell
  python run_zlint.py --dir "zlint" --pattern "*/positive/*.pem" --zlint "zlint.exe"
  ```
- `--include`：只运行某个 lint 名（同 `-includeNames`）。

批量模式的行为：
- 每个证书单独保存 `<证书>.zlint.json` 与 `<证书>.zlint.summary.json`（仅含 error/warn/fatal）。
- 额外在文件夹下生成 `<文件夹名>.batch.summary.json`，汇总所有证书的命中结果，并打印命中证书数与检查总数。

### 方式二 —— 从源码运行（需 Python）

```powershell
python run_zlint.py
```
或直接双击 `run_zlint.bat`。

### 重新打包

```powershell
pyinstaller --onefile --console --name run_zlint run_zlint.py
```
或双击 `build.bat`，生成的 exe 位于 `dist/run_zlint.exe`。

## 注意事项

- 本工具**不含 zlint 本体**，你需要自己提供 `zlint` 可执行文件。
- 父仓库根目录附带的 `zlint.exe` 是 **3.6.8 版本**——这是 zlint 最后一个仍提供 Windows 预编译二进制的发布版本。更新版本已取消 Windows（和 FreeBSD）的发布目标，因此在 Windows 上要么沿用 3.6.8，要么自行从源码编译更新的版本。
- 当 zlint 报告 `error` 结果时，进程会以非 0 退出码结束，这是正常现象，不代表本工具失败。
- 父项目里的证书样本位于 `../zlint/<组>/<条目>/positive/` 目录下。
- 想直接查看证书内部字段（主题、扩展、`certificatePolicies` 是否为空等），可用父目录的 [`../decode_cert.py`](../decode_cert.py)：`python ../decode_cert.py 证书.pem`。
