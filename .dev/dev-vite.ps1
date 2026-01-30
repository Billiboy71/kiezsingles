$ProjectDir = "C:\laragon\www\kiezsingles"
$NpmCmd     = "C:\Program Files\nodejs\npm.cmd"

Set-Location $ProjectDir

Write-Host "Starting Vite dev server..."
& $NpmCmd run dev
