@echo off
rem IT Technician Toolkit - start with administrator rights
title IT Technician Toolkit (Admin)
cd /d "%~dp0"
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0Launcher\Toolkit.ps1"
exit /b
