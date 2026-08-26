# ZT-034 实测复现记录

> 记录使用本项目的 `zlint.exe`（v3.6.8）实际运行 `ZT-034` 的 `repro.sh` 的结果与解读。
> 缺陷本身的原理见 [`zlint/04-predicate/ZT-034-e_sub_cert_cert_policy_empty/README.md`](zlint/04-predicate/ZT-034-e_sub_cert_cert_policy_empty/README.md)。

## 缺陷摘要

| 项 | 内容 |
|---|---|
| **Lint** | `e_sub_cert_cert_policy_empty` |
| **工具** | `zmap/zlint` |
| **分组** | `04-predicate` — 测试本身逻辑有误 |
| **断言** | 证书中 `certificatePolicies` 扩展存在、但其值为空的 `SEQUENCE`（30 00，零个 policy identifier）时，本应判 `error` |
| **实际（bug）** | 该 lint 守卫条件写成 `c.PolicyIdentifiers != nil`，zcrypto 把空 `SEQUENCE` 解析成**非 nil 的零长切片**，导致守卫通过、lint 返回 `pass` |
| **修复建议** | 改为 `len(c.PolicyIdentifiers) > 0` |

## 运行命令

在 Git Bash 中（注意 Windows 路径要写成 `/c/...` 形式）：

```bash
cd C:/Users/nizhou/Downloads/linter-triage-2026-08-24/linter-triage-2026-08-24/zlint

bash "/c/Users/nizhou/Downloads/linter-triage-2026-08-24/linter-triage-2026-08-24/zlint/04-predicate/ZT-034-e_sub_cert_cert_policy_empty/repro.sh" \
     "/c/Users/nizhou/Downloads/linter-triage-2026-08-24/linter-triage-2026-08-24/zlint.exe"
```

> 注意：`repro.sh` 的第一个参数（zlint 可执行文件）必须能正确解析。
> 若在 `zlint/` 子目录下运行，相对路径 `"zlint.exe"` 会因文件实际在**项目根目录**而报
> `command not found`；务必传**绝对路径**且使用 Git Bash 的 `/c/...` 写法。

## 实际输出

```text
{"e_sub_cert_cert_policy_empty":{"result":"pass"}}

observed  pass
correct   error - the extension is present and asserts no policy identifier
```

## 解读

- `{"result":"pass"}` —— 本项目 `zlint.exe`（v3.6.8）对 positive 样本证书实际跑出来的结果。
- 脚本末尾的 `observed pass / correct error` 一部分是**硬编码说明文字**，但此处与真实输出一致，
  因此本次复现成功：当前 zlint 对该"本应报 `error`"的证书给出了 `pass`，证明 ZT-034 所述 bug
  在 v3.6.8 中确实存在。

## 结论

`repro.sh` 通过"固定 positive 样本 + 只跑对应一条 lint"，把**观察到的**与**正确的**结果并排打印，
以此证明该 bug 真实存在。本次运行即一次完整、成功的复现。
