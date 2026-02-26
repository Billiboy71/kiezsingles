$ProjectDir = "C:\laragon\www\kiezsingles"
$PhpExe     = "C:\laragon\bin\php\php-8.5.1-nts-Win32-vs17-x64\php.exe"

Set-Location $ProjectDir

Write-Host "Starting Laravel on port 8000..."
& $PhpExe artisan serve --port=8000
