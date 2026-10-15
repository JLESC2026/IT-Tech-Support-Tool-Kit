@echo off
rem IT Technician Toolkit - normal start (asks for admin only when a tool needs it)
title IT Technician Toolkit
cd /d "%~dp0"
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0Launcher\Toolkit.ps1"
exit /b
