@echo off
rem 用 PyInstaller 把 run_zlint.py 打包成独立 exe (自带 Python 运行时)
rem 生成的 exe 位于 dist\run_zlint.exe
pyinstaller --onefile --console --name run_zlint run_zlint.py
echo.
echo 打包完成，exe 位于 dist\run_zlint.exe
pause
