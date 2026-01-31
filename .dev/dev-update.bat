:: ============================================================================
:: File: C:\laragon\dev-update.bat
:: Purpose: Update development tools (Node.js LTS via winget, optional Composer)
:: Notes:
::  - Updates KEINE Projekt-Abhängigkeiten (kein npm/composer update im Projekt)
::  - Sicher, reproduzierbar, bewusst manuell starten
:: ============================================================================

@echo off
setlocal EnableExtensions

echo.
echo ============================================================
echo   Dev Update
echo ============================================================
echo.

REM --- winget muss vorhanden sein ---
where winget >nul 2>nul
if errorlevel 1 (
  echo [ERROR] winget not found. Aborting.
  exit /b 1
)

REM --- Node.js LTS updaten ---
echo [winget] Updating Node.js (LTS)...
winget upgrade --id OpenJS.NodeJS.LTS -e ^
  --accept-package-agreements --accept-source-agreements

echo.
echo [info] Current Node/npm versions:
echo   node:
node -v
echo   npm:
npm -v

REM --- Optional: Composer (nur global, nur wenn vorhanden) ---
where composer >nul 2>nul
if errorlevel 1 (
  echo.
  echo [composer] not found - skipping.
) else (
  echo.
  echo [composer] self-update...
  composer self-update
  echo [composer] global update...
  composer global update
)

echo.
echo ============================================================
echo   Update finished.
echo ============================================================
echo.

endlocal
exit /b 0
