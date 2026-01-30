$ProjectDir = "C:\laragon\www\kiezsingles"
$PhpExe     = "C:\laragon\bin\php\php-8.3.28-Win32-vs16-x64\php.exe"

Set-Location $ProjectDir

Write-Host "Starting Laravel on port 8000..."
& $PhpExe artisan serve --port=8000
