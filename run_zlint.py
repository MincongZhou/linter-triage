#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
交互式运行 zlint 检查证书，并保存输出结果到文件。

用法:
    python run_zlint.py
然后按提示输入:
    1) zlint 可执行文件的位置 (如 C:\...\zlint.exe 或 /c/...\zlint.exe)
    2) 要检查的证书文件位置 (支持 .pem / .der / .crt / .cer)
    3) (可选) 只运行指定的 lint (-includeNames)，留空表示全部

结果会同时打印到屏幕，并保存为 <证书名>.zlint.json (默认)。
"""

import json
import os
import subprocess
import sys

OUTPUT_SUFFIX = ".zlint.json"


def prompt_path(label, must_exist=True):
    """让用户输入一个路径，做基本的存在性/可读性检查。"""
    while True:
        val = input(f"{label}: ").strip().strip('"').strip("'")
        if not val:
            print("  请输入一个有效路径，不能为空。")
            continue
        if must_exist and not os.path.exists(val):
            print(f"  路径不存在: {val}")
            retry = input("  仍要继续? (y/N): ").strip().lower()
            if retry != "y":
                continue
            return val
        return val


def main():
    print("=" * 60)
    print("  zlint 交互式证书检查工具")
    print("=" * 60)

    zlint_bin = prompt_path("请输入 zlint 可执行文件位置 (如 zlint.exe)")
    cert_path = prompt_path("请输入要检查的证书文件位置 (如 xxx.pem)")

    include = input("可选: 只运行某个 lint 名 (-includeNames，留空=全部): ").strip()

    cmd = [zlint_bin, cert_path]
    if include:
        cmd.insert(1, "-includeNames=" + include)

    print("\n运行命令: " + " ".join(cmd))
    print("-" * 60)

    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        print(f"[错误] 找不到可执行文件: {zlint_bin}")
        print("        请确认路径是否正确，或在 PATH 中可直接调用 zlint。")
        sys.exit(1)
    except Exception as e:  # noqa: BLE001
        print(f"[错误] 运行失败: {e}")
        sys.exit(1)

    stdout = proc.stdout
    stderr = proc.stderr

    # 打印到屏幕
    if stdout:
        print(stdout)
    if stderr:
        print("[stderr]\n" + stderr)

    if proc.returncode != 0:
        print(f"[提示] 进程返回码: {proc.returncode} (非 0 不一定代表失败，"
              "zlint 对 error 结果常返回非 0)")

    # 保存结果
    base, _ = os.path.splitext(cert_path)
    out_path = base + OUTPUT_SUFFIX
    try:
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(stdout)
            if stderr:
                f.write("\n\n[stderr]\n" + stderr)
        print("-" * 60)
        print(f"[已保存] {out_path}")
    except Exception as e:  # noqa: BLE001
        print(f"[警告] 保存失败: {e}")

    # 如果输出是 JSON，额外给一个"只看 error/warn/fatal"的汇总文件
    try:
        data = json.loads(stdout)
        flagged = {
            k: v for k, v in data.items()
            if isinstance(v, dict) and v.get("result") in ("error", "warn", "fatal")
        }
        if flagged:
            summary_path = base + ".zlint.summary.json"
            with open(summary_path, "w", encoding="utf-8") as f:
                json.dump(flagged, f, indent=2, ensure_ascii=False)
            print(f"[已保存] {summary_path} (仅含 error/warn/fatal)")
            print(f"         命中 {len(flagged)} 条检查")
    except json.JSONDecodeError:
        # 非 JSON 输出 (比如 -format=text)，跳过汇总
        pass


if __name__ == "__main__":
    main()
