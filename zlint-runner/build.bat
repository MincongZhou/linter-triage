@echo off
rem 用 PyInstaller 把脚本打包成独立 exe (自带 Python 运行时)
rem 生成的 exe 位于 dist\run_zlint.exe 与 dist\audit_coverage.exe

rem 1) run_zlint (交互式证书检查)
pyinstaller --onefile --console --name run_zlint run_zlint.py
echo.
echo 打包完成，exe 位于 dist\run_zlint.exe

rem 2) audit_coverage (审计覆盖表, 可选)
pyinstaller audit_coverage.spec --noconfirm
echo.
echo 打包完成，exe 位于 dist\audit_coverage.exe
pause
