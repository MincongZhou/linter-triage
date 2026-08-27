#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
交互式运行 zlint 检查证书，并保存输出结果到文件。

运行时按提示操作:
    1) zlint 可执行文件的位置 (如 C:\...\zlint.exe 或 /c/...\zlint.exe)
    2) 是否批量检查一个文件夹里的所有证书? (y/N)
       - 选 y: 输入文件夹位置，递归遍历其中所有证书 (.pem/.der/.crt/.cer)
       - 选 n: 输入单个证书文件位置
    3) (可选) 只运行指定的 lint (-includeNames)，留空表示全部

结果会同时打印到屏幕，并保存为 <证书名>.zlint.json (默认)；
批量模式还会额外生成 <文件夹名>.batch.summary.json 汇总所有命中。

也支持纯命令行 (无交互):
    python run_zlint.py --dir 文件夹 [--zlint 路径] [--include lint] [--pattern "*.pem"]
    python run_zlint.py --cert 证书文件 [--zlint 路径] [--include lint]
"""

import argparse
import glob
import json
import os
import subprocess
import sys

from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment

OUTPUT_SUFFIX = ".zlint.json"
CERT_EXTS = (".pem", ".der", ".crt", ".cer")

# zlint 结果码 -> 中文含义，用于在 Excel 中"描述检测内容"
RESULT_MEANING = {
    "error": "错误：证书不符合规范要求，应被拒绝",
    "fatal": "致命错误：解析/结构层面无法处理",
    "warn": "警告：不推荐但不一定违规",
    "pass": "通过：符合该条检查要求",
    "info": "信息：仅供参考",
    "NA": "不适用：该检查对此证书不适用",
    "notice": "提示：需注意",
}
RESULT_FILL = {
    "error": "FFC7CE",   # 红
    "fatal": "FF9999",   # 深红
    "warn": "FFEB9C",    # 黄
    "pass": "C6EFCE",    # 绿
    "NA": "D9D9D9",      # 灰
}


def prompt_path(label, must_exist=True):
    """让用户输入一个路径，做基本的存在性/可读性检查。"""
    while True:
        val = input(f"{label}: ").strip().lstrip("\ufeff").strip('"').strip("'")
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


def write_xlsx(base, data, cert_name=""):
    """把 zlint 的 JSON 结果写成 Excel 表格，描述每条检测内容。

    列: 序号 | Lint 名称 | 结果 | 结果含义 | 详情
    返回生成的 xlsx 路径；data 不是 dict 时返回 None。
    """
    if not isinstance(data, dict):
        return None

    rows = []
    for name, info in data.items():
        if not isinstance(info, dict):
            continue
        result = info.get("result", "")
        details = info.get("details", "") or ""
        rows.append((name, result, RESULT_MEANING.get(result, result), details))

    wb = Workbook()
    ws = wb.active
    ws.title = "检测结果"
    headers = ["序号", "Lint 名称", "结果", "结果含义", "详情"]
    ws.append(headers)
    hdr_fill = PatternFill("solid", fgColor="305496")
    hdr_font = Font(bold=True, color="FFFFFF")
    for c in range(1, len(headers) + 1):
        cell = ws.cell(row=1, column=c)
        cell.fill = hdr_fill
        cell.font = hdr_font
        cell.alignment = Alignment(vertical="center")

    for i, (name, result, meaning, details) in enumerate(rows, 1):
        ws.append([i, name, result, meaning, details])
        fill = RESULT_FILL.get(result)
        if fill:
            ws.cell(row=i + 1, column=3).fill = PatternFill("solid", fgColor=fill)

    # 列宽
    ws.column_dimensions["A"].width = 6
    ws.column_dimensions["B"].width = 48
    ws.column_dimensions["C"].width = 10
    ws.column_dimensions["D"].width = 40
    ws.column_dimensions["E"].width = 60
    ws.freeze_panes = "A2"

    xlsx_path = base + ".zlint.xlsx"
    try:
        wb.save(xlsx_path)
    except Exception as e:  # noqa: BLE001
        print(f"[警告] 保存 Excel 失败: {e}")
        return None
    return xlsx_path


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

    if verbose:
        if stdout:
            print(stdout)
        if stderr:
            print("[stderr]\n" + stderr)
        if proc.returncode != 0:
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

        # 额外生成 Excel 表格，描述每条检测内容
        xlsx_path = write_xlsx(base, data)
        if xlsx_path and verbose:
            print(f"[已保存] {xlsx_path} (Excel 表格: 每条 lint 的结果与说明)")
    except json.JSONDecodeError:
        pass

    return out_path, flagged


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
    files = [
        f for f in files
        if os.path.isfile(f)
        and not f.endswith(OUTPUT_SUFFIX)
        and not f.endswith(".zlint.summary.json")
    ]
    return sorted(set(os.path.abspath(f) for f in files))


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

    # 额外生成批量汇总 Excel：每行一个证书，列出命中数与命中的 lint
    batch_xlsx = os.path.join(folder, f"{base}.batch.xlsx")
    try:
        wb = Workbook()
        ws = wb.active
        ws.title = "批量汇总"
        ws.append(["证书", "命中数", "命中的 lint (error/warn/fatal)"])
        for c in range(1, 4):
            cell = ws.cell(row=1, column=c)
            cell.fill = PatternFill("solid", fgColor="305496")
            cell.font = Font(bold=True, color="FFFFFF")
        for cert, fl in summary.items():
            lint_names = ", ".join(
                f"{k}={v.get('result')}" for k, v in fl.items()
            )
            ws.append([os.path.basename(cert), len(fl), lint_names])
        ws.column_dimensions["A"].width = 50
        ws.column_dimensions["B"].width = 10
        ws.column_dimensions["C"].width = 80
        ws.freeze_panes = "A2"
        wb.save(batch_xlsx)
        print(f"批量汇总 Excel: {batch_xlsx}")
    except Exception as e:  # noqa: BLE001
        print(f"[警告] 批量汇总 Excel 生成失败: {e}")


def interactive_mode():
    print("=" * 60)
    print("  zlint 交互式证书检查工具")
    print("=" * 60)

    zlint_bin = prompt_path("请输入 zlint 可执行文件位置 (如 zlint.exe)")

    choice = input("是否批量检查一个文件夹里的所有证书? (y/N): ").strip().lstrip("\ufeff").lower()
    include = input("可选: 只运行某个 lint 名 (-includeNames，留空=全部): ").strip().lstrip("\ufeff")

    if choice == "y":
        folder = prompt_path("请输入证书文件夹位置 (将递归遍历所有证书)", must_exist=True)
        batch_mode(zlint_bin, folder, None, include)
    else:
        cert_path = prompt_path("请输入要检查的证书文件位置 (如 xxx.pem)")
        run_one(zlint_bin, cert_path, include, verbose=True)


def main():
    parser = argparse.ArgumentParser(
        description="运行 zlint 检查证书（交互式选择单张/批量，或命令行指定）")
    parser.add_argument("--dir", help="证书文件夹，批量模式（递归遍历）")
    parser.add_argument("--cert", help="单个证书文件，单张模式")
    parser.add_argument("--zlint", help="zlint 可执行文件路径")
    parser.add_argument("--include", help="只运行某个 lint 名 (-includeNames)")
    parser.add_argument("--pattern", help="批量模式的文件匹配 glob，如 '*/positive/*.pem'")
    args = parser.parse_args()

    if args.dir:
        if not args.zlint:
            print("[错误] --dir 模式需要 --zlint 指定 zlint 可执行文件。")
            sys.exit(1)
        if not os.path.isdir(args.dir):
            print(f"[错误] 文件夹不存在: {args.dir}")
            sys.exit(1)
        batch_mode(args.zlint, args.dir, args.pattern, args.include)
    elif args.cert:
        if not args.zlint:
            print("[错误] --cert 模式需要 --zlint 指定 zlint 可执行文件。")
            sys.exit(1)
        if not os.path.isfile(args.cert):
            print(f"[错误] 文件不存在: {args.cert}")
            sys.exit(1)
        run_one(args.zlint, args.cert, args.include, verbose=True)
    else:
        interactive_mode()

    try:
        input("\n按回车退出...")
    except EOFError:
        pass


if __name__ == "__main__":
    main()
