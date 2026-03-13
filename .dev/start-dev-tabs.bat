@echo off
setlocal

REM ============================================================================
REM Start Laragon (on-demand, kein Dienst)
REM ============================================================================
set "LARAGON_EXE=C:\laragon\laragon.exe"
set "FIREFOX_EXE=C:\Program Files\Mozilla Firefox\firefox.exe"
set "APP_URL=http://kiezsingles.test"

if exist "%LARAGON_EXE%" (
    echo Starting Laragon...
    start "" "%LARAGON_EXE%"
    REM kurze Pause, damit MySQL sicher hochkommt
    timeout /t 6 >nul
) else (
    echo Laragon not found at %LARAGON_EXE%
)

REM ============================================================================
REM AB HIER: DEIN CODE – UNVERÄNDERT
REM ============================================================================

set "PROJECT_DIR=C:\laragon\www\kiezsingles"
set "DEV_DIR=%PROJECT_DIR%\.dev"
set "WT=%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe"

"%WT%" -w new ^
  new-tab --title "Laravel 8000" --startingDirectory "%PROJECT_DIR%" ^
    pwsh -NoExit -ExecutionPolicy Bypass -File "%DEV_DIR%\dev-laravel.ps1" ^
  ; new-tab --title "Vite" --startingDirectory "%PROJECT_DIR%" ^
    pwsh -NoExit -ExecutionPolicy Bypass -File "%DEV_DIR%\dev-vite.ps1" ^
  ; new-tab --title "Shell" --startingDirectory "%PROJECT_DIR%" ^
    pwsh -NoExit

timeout /t 3 >nul

if exist "%FIREFOX_EXE%" (
    start "" "%FIREFOX_EXE%" "%APP_URL%"
) else (
    start "" "%APP_URL%"
)

endlocal