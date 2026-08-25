@echo off
rem 双击此文件即可运行 run_zlint.py（交互式 zlint 证书检查工具）
set PYTHON=python
set SCRIPT=%~dp0run_zlint.py

"%PYTHON%" "%SCRIPT%"
if errorlevel 1 (
    echo.
    echo [错误] 运行失败。请确认已安装 Python 且在 PATH 中。
)
echo.
echo 按任意键关闭窗口...
pause >nul
