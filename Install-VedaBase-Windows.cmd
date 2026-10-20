@echo off
rem Double-click to install the Bhaktivedanta VedaBase on Windows 10 or 11.
rem It runs windows\install-vedabase.ps1, which asks for administrator rights.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows\install-vedabase.ps1" %*
if errorlevel 1 pause
