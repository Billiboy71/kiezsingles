$ProjectDir = "C:\laragon\www\kiezsingles"
$PhpExe     = "C:\laragon\bin\php\current\php.exe"

Set-Location $ProjectDir

Write-Host "Starting Laravel on port 8000..."
& $PhpExe artisan serve --port=8000
