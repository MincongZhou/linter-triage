#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
解码 X.509 证书（PEM 或 DER），以可读形式打印其内容。

用法:
    单张证书:
        python decode_cert.py cert.pem
        python decode_cert.py cert.der
    批量（递归遍历文件夹下所有 .pem/.der/.crt/.cer）:
        python decode_cert.py cert-folder
    从命令行直接粘 PEM（用 - 表示 stdin）:
        type cert.pem | python decode_cert.py -

依赖:
    pip install cryptography
"""

import argparse
import sys
import os
import glob

# Windows 控制台默认 GBK，遇到非 ASCII（如ö）会编码失败；强制 UTF-8 输出。
if sys.stdout.encoding and sys.stdout.encoding.lower() not in ("utf-8", "utf8"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

try:
    from cryptography import x509
    from cryptography.hazmat.primitives import serialization
except ImportError:
    print("[错误] 需要 cryptography 库。请运行: pip install cryptography")
    sys.exit(1)

CERT_EXTS = (".pem", ".der", ".crt", ".cer")


def load_cert(path):
    """从文件加载证书，自动识别 PEM / DER。"""
    with open(path, "rb") as f:
        data = f.read()
    try:
        return x509.load_pem_x509_certificate(data)
    except ValueError:
        try:
            return x509.load_der_x509_certificate(data)
        except ValueError:
            raise ValueError(f"无法解析为 PEM 或 DER 证书: {path}")


def decode_cert(cert):
    lines = []
    a = lines.append

    def name_to_str(n):
        try:
            return n.rfc4514_string()
        except Exception:
            return str(n)

    a("主题 (Subject):      " + name_to_str(cert.subject))
    a("签发者 (Issuer):     " + name_to_str(cert.issuer))
    a("序列号 (Serial):     " + format(cert.serial_number, "x"))
    a("版本 (Version):      v" + str(cert.version.value))
    a("有效期从:            " + cert.not_valid_before_utc.isoformat())
    a("有效期至:            " + cert.not_valid_after_utc.isoformat())
    a("签名算法:            " + cert.signature_algorithm_oid._name)

    # 公钥
    try:
        pub = cert.public_key()
        pub_der = pub.public_bytes(
            serialization.Encoding.DER,
            serialization.PublicFormat.SubjectPublicKeyInfo,
        )
        a("公钥算法:            " + type(pub).__name__)
        a("公钥大小 (bits):     " + str(pub.key_size))
        a("公钥 (hex, 简略):    " + pub_der.hex()[:64] + "...")
    except Exception as e:
        a("公钥:                (无法解析: %s)" % e)

    # 扩展
    a("")
    a("扩展 (%d 个):" % len(cert.extensions))
    for ext in cert.extensions:
        a("  - " + ext.oid._name)
        a("      critical = " + str(ext.critical))
        try:
            val = ext.value
            # 常用扩展的友好展示
            if isinstance(val, x509.SubjectAlternativeName):
                a("      " + ", ".join(str(g) for g in val))
            elif isinstance(val, x509.BasicConstraints):
                a("      CA=%s, path_len=%s" % (val.ca, val.path_length))
            elif isinstance(val, x509.KeyUsage):
                a("      " + str(val).replace("\n", " | "))
            elif isinstance(val, x509.ExtendedKeyUsage):
                a("      " + ", ".join(str(u) for u in val))
            else:
                a("      " + str(val).replace("\n", "  "))
        except Exception as e:
            a("      (展示失败: %s)" % e)

    return "\n".join(lines)


def main():
    p = argparse.ArgumentParser(description="解码 X.509 证书 (PEM/DER)")
    p.add_argument("target", help="证书文件、文件夹，或 - (stdin)")
    args = p.parse_args()

    if args.target == "-":
        data = sys.stdin.buffer.read()
        try:
            cert = x509.load_pem_x509_certificate(data)
        except ValueError:
            cert = x509.load_der_x509_certificate(data)
        print(decode_cert(cert))
        return

    if os.path.isdir(args.target):
        files = []
        for root, _d, names in os.walk(args.target):
            for n in names:
                if n.lower().endswith(CERT_EXTS):
                    files.append(os.path.join(root, n))
        files = sorted(set(files))
        if not files:
            print("[错误] 文件夹下未发现证书文件。")
            sys.exit(1)
        for i, fp in enumerate(files, 1):
            print("=" * 70)
            print("[%d/%d] %s" % (i, len(files), fp))
            print("=" * 70)
            try:
                cert = load_cert(fp)
                print(decode_cert(cert))
            except Exception as e:
                print("[失败] %s" % e)
            print()
        return

    if not os.path.isfile(args.target):
        print("[错误] 文件不存在: %s" % args.target)
        sys.exit(1)

    try:
        cert = load_cert(args.target)
    except Exception as e:
        print("[错误] %s" % e)
        sys.exit(1)
    print(decode_cert(cert))


if __name__ == "__main__":
    main()
