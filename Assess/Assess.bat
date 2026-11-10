@echo off
rem Double-click to run the PC assessment. It asks for administrator rights and saves one HTML report.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Assess.ps1"
