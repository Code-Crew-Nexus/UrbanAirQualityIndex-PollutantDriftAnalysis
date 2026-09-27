# scripts/start_website_preview.ps1
# Windows PowerShell convenience launcher for Urban Air Quality local website preview

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectRoot = Split-Path -Parent $ScriptDir
$ServerScript = Join-Path $ScriptDir "serve_website_local.py"

Write-Host "Starting Urban Air Quality Local Preview..." -ForegroundColor Cyan

if (Get-Command py -ErrorAction SilentlyContinue) {
    & py $ServerScript @args
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
    & python $ServerScript @args
} else {
    Write-Error "Python 3 is required but was not found on PATH. Please install Python or use: py -m http.server 8000 --directory docs"
    exit 1
}
