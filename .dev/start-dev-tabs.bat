@echo off
setlocal

set "PROJECT_DIR=C:\laragon\www\kiezsingles"
set "DEV_DIR=%PROJECT_DIR%\.dev"
set "WT=%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe"

REM Windows Terminal starten: 1 Fenster, 4 Tabs
"%WT%" -w new ^
  new-tab --title "Laravel 8000" --startingDirectory "%PROJECT_DIR%" ^
    powershell -NoExit -ExecutionPolicy Bypass -File "%DEV_DIR%\dev-laravel.ps1" ^
  ; new-tab --title "Vite" --startingDirectory "%PROJECT_DIR%" ^
    powershell -NoExit -ExecutionPolicy Bypass -File "%DEV_DIR%\dev-vite.ps1" ^
  ; new-tab --title "BrowserSync" --startingDirectory "%PROJECT_DIR%" ^
    powershell -NoExit -ExecutionPolicy Bypass -File "%DEV_DIR%\dev-browsersync.ps1" ^
  ; new-tab --title "Shell" --startingDirectory "%PROJECT_DIR%" ^
    powershell -NoExit

endlocal
