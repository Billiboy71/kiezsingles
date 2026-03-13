@echo off
REM ============================================================================
REM File: C:\laragon\www\kiezsingles\tools\audit\ks-admin-audit-gui.cmd
REM Purpose: Desktop launcher for KiezSingles Admin Audit GUI (UI-only, no fallback)
REM Created: 19-02-2026 23:50 (Europe/Berlin)
REM Changed: 14-03-2026 00:10 (Europe/Berlin)
REM Version: 1.9
REM ============================================================================

SETLOCAL ENABLEEXTENSIONS

REM UI script (required; no fallback)
SET "SCRIPT_UI=C:\laragon\www\kiezsingles\tools\audit\ks-admin-audit-ui.ps1"

IF NOT EXIST "%SCRIPT_UI%" (
    echo.
    echo Audit UI script not found:
    echo   %SCRIPT_UI%
    echo.
    pause
    exit /b 1
)

REM Ensure predictable working directory (project root)
pushd "C:\laragon\www\kiezsingles" >nul 2>&1

echo.
echo Launching Audit UI:
echo   %SCRIPT_UI%
echo.

REM Detached start (so this CMD can exit) with normal PowerShell window.
REM -STA is required for reliable WinForms + Clipboard behavior.
start "" powershell.exe -NoLogo -STA -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_UI%"

set "EC=0"

popd >nul 2>&1

exit /b %EC%
