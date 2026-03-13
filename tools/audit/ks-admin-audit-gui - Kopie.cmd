@echo off
REM ============================================================================
REM File: C:\laragon\www\kiezsingles\tools\audit\ks-admin-audit-gui.cmd
REM Purpose: Desktop launcher for KiezSingles Admin Audit GUI (UI-only, no fallback)
REM Created: 19-02-2026 23:50 (Europe/Berlin)
REM Changed: 20-02-2026 21:59 (Europe/Berlin)
REM Version: 1.5
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

echo.
echo Launching Audit UI:
echo   %SCRIPT_UI%
echo.

REM Run UI via -File (no -Command string parsing).
REM -STA is required for reliable WinForms + Clipboard behavior.
powershell.exe -NoLogo -STA -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_UI%"

set "EC=%ERRORLEVEL%"

echo.
echo ExitCode: %EC%
echo.

REM Always keep window open so errors are visible even on success.
pause

exit /b %EC%