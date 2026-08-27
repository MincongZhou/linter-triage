# -*- mode: python ; coding: utf-8 -*-
# audit_coverage.py 打包配置 (与 run_zlint.spec 一致, 内含 lint_rules.json)
# 用法: cd zlint-runner && pyinstaller audit_coverage.spec

a = Analysis(
    ['../audit_coverage.py'],
    pathex=[],
    binaries=[],
    datas=[('lint_rules.json', '.')],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='audit_coverage',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
