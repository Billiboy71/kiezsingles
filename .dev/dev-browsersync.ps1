$ProjectDir = "C:\laragon\www\kiezsingles"
$NodeExe    = "C:\Program Files\nodejs\node.exe"

Set-Location $ProjectDir

Write-Host "Starting BrowserSync (proxy localhost:8000)..."
& $NodeExe .\node_modules\browser-sync\dist\bin.js start `
  --proxy "http://localhost:8000" `
  --files "resources/views/**/*.blade.php,resources/**/*.css,resources/**/*.js,public/**/*" `
  --no-notify
