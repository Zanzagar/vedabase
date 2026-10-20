@echo off
rem Double-click to install the Bhaktivedanta VedaBase on Windows 10 or 11.
rem It runs windows\install-vedabase.ps1, which asks for administrator rights.
if not exist "%~dp0windows\install-vedabase.ps1" (
  echo This installer must run from the unzipped folder.
  echo Right-click the ZIP file, choose "Extract All", then open the new folder
  echo and double-click Install-VedaBase-Windows.cmd there.
  echo.
  pause
  exit /b 1
)
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows\install-vedabase.ps1" %*
if not "%errorlevel%"=="0" pause
