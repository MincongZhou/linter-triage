#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
交互式运行 zlint 检查证书，并保存输出结果到文件。
支持单张证书（交互式）或批量遍历一个文件夹里的所有证书。

用法:
    run_zlint.exe                 # 双击，按提示输入（单张证书）
或
    python run_zlint.py           # 同上，交互式单张
或（批量模式，无需交互）:
    python run_zlint.py --dir 证书文件夹 [--zlint zlint路径] [--include lint名] [--pattern "*.pem"]
    python run_zlint.py --dir zlint --pattern "*/positive/*.pem" --zlint zlint.exe

按提示输入（交互模式）:
    1) zlint 可执行文件的位置 (如 C:\...\zlint.exe 或 /c/...\zlint.exe)
    2) 要检查的证书文件位置 (支持 .pem / .der / .crt / .cer)
    3) (可选) 只运行指定的 lint (-includeNames)，留空表示全部

结果会同时打印到屏幕，并保存为 <证书名>.zlint.json (默认)。
批量模式会额外生成一个 <文件夹名>.batch.summary.json 汇总所有命中。
"""

import argparse
import glob
import json
import os
import subprocess
import sys

OUTPUT_SUFFIX = ".zlint.json"
CERT_EXTS = (".pem", ".der", ".crt", ".cer")


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


def find_cert_files(folder, pattern=None):
    """返回文件夹（递归）下所有证书文件。pattern 为相对文件夹的 glob。"""
    files = []
    if pattern:
        files = glob.glob(os.path.join(folder, pattern), recursive=True)
    else:
        for root, _dirs, names in os.walk(folder):
            for n in names:
                if n.lower().endswith(CERT_EXTS):
                    files.append(os.path.join(root, n))
    # 过滤掉已生成的输出文件，排除目录自身
    files = [
        f for f in files
        if os.path.isfile(f)
        and not f.endswith(OUTPUT_SUFFIX)
        and not f.endswith(".zlint.summary.json")
    ]
    return sorted(set(os.path.abspath(f) for f in files))


def run_one(zlint_bin, cert_path, include, verbose=True):
    """运行一次 zlint 并检查单个证书，保存结果；返回 (saved_json_path, flagged_dict)。"""
    cmd = [zlint_bin, cert_path]
    if include:
        cmd.insert(1, "-includeNames=" + include)

    if verbose:
        print("\n运行命令: " + " ".join(cmd))
        print("-" * 60)

    try:
        proc = subprocess.run(cmd, capture_output=True, text=True)
    except FileNotFoundError:
        print(f"[错误] 找不到可执行文件: {zlint_bin}")
        print("        请确认路径是否正确，或在 PATH 中可直接调用 zlint。")
        return None, None
    except Exception as e:  # noqa: BLE001
        print(f"[错误] 运行失败: {e}")
        return None, None

    stdout = proc.stdout
    stderr = proc.stderr

    if verbose and stdout:
        print(stdout)
    if verbose and stderr:
        print("[stderr]\n" + stderr)

    if verbose and proc.returncode != 0:
        print(f"[提示] 进程返回码: {proc.returncode} (非 0 不一定代表失败，"
              "zlint 对 error 结果常返回非 0)")

    base, _ = os.path.splitext(cert_path)
    out_path = base + OUTPUT_SUFFIX
    try:
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(stdout)
            if stderr:
                f.write("\n\n[stderr]\n" + stderr)
        if verbose:
            print("-" * 60)
            print(f"[已保存] {out_path}")
    except Exception as e:  # noqa: BLE001
        print(f"[警告] 保存失败: {e}")

    flagged = {}
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
            if verbose:
                print(f"[已保存] {summary_path} (仅含 error/warn/fatal)")
                print(f"         命中 {len(flagged)} 条检查")
    except json.JSONDecodeError:
        pass

    return out_path, flagged


def batch_mode(zlint_bin, folder, pattern, include):
    certs = find_cert_files(folder, pattern)
    if not certs:
        print(f"[错误] 在 {folder} 下未发现证书文件"
              + (f" (pattern={pattern})" if pattern else ""))
        sys.exit(1)

    print("=" * 60)
    print(f"  批量模式: 共发现 {len(certs)} 个证书")
    print(f"  文件夹: {folder}")
    if pattern:
        print(f"  匹配:  {pattern}")
    print("=" * 60)

    summary = {}
    for i, cert in enumerate(certs, 1):
        print(f"\n[{i}/{len(certs)}] {cert}")
        _out, flagged = run_one(zlint_bin, cert, include, verbose=False)
        if flagged:
            summary[cert] = flagged

    # 汇总文件
    base = os.path.basename(os.path.normpath(folder))
    batch_summary_path = os.path.join(folder, f"{base}.batch.summary.json")
    with open(batch_summary_path, "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2, ensure_ascii=False)

    print("\n" + "=" * 60)
    print(f"完成。{len(certs)} 个证书已处理，"
          f"其中 {len(summary)} 个有 error/warn/fatal。")
    print(f"批量汇总: {batch_summary_path}")
    total = sum(len(v) for v in summary.values())
    print(f"命中检查总数: {total}")


def interactive_mode():
    print("=" * 60)
    print("  zlint 交互式证书检查工具")
    print("=" * 60)

    zlint_bin = prompt_path("请输入 zlint 可执行文件位置 (如 zlint.exe)")
    cert_path = prompt_path("请输入要检查的证书文件位置 (如 xxx.pem)")
    include = input("可选: 只运行某个 lint 名 (-includeNames，留空=全部): ").strip()

    run_one(zlint_bin, cert_path, include, verbose=True)


def main():
    parser = argparse.ArgumentParser(
        description="运行 zlint 检查证书（单张交互 / 批量遍历文件夹）")
    parser.add_argument("--dir", help="证书文件夹，启用批量模式（递归遍历）")
    parser.add_argument("--zlint", help="zlint 可执行文件路径（批量模式必填）")
    parser.add_argument("--include", help="只运行某个 lint 名 (-includeNames)")
    parser.add_argument("--pattern", help="批量模式的文件匹配 glob，如 '*/positive/*.pem'")
    args = parser.parse_args()

    if args.dir:
        if not args.zlint:
            print("[错误] 批量模式需要 --zlint 指定 zlint 可执行文件。")
            sys.exit(1)
        if not os.path.isdir(args.dir):
            print(f"[错误] 文件夹不存在: {args.dir}")
            sys.exit(1)
        batch_mode(args.zlint, args.dir, args.pattern, args.include)
    else:
        interactive_mode()


if __name__ == "__main__":
    main()
