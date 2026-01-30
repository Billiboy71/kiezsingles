@echo off
cd /d C:\laragon\www\kiezsingles

node .\node_modules\browser-sync\dist\bin.js start ^
  --proxy "http://localhost:8000" ^
  --files "resources/views/**/*.blade.php,resources/**/*.css,resources/**/*.js,public/**/*" ^
  --no-notify
