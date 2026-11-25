@echo off
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0Iniciar-Nexus.ps1" %*
if errorlevel 1 pause
