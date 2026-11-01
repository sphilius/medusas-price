# play_web.ps1 - dev-only: export the Web build, serve it, open it in the browser.
#
#   .\tools\play_web.ps1              export, serve on :8060, open the browser
#   .\tools\play_web.ps1 -NoBrowser   same, but don't open a browser tab
#
# Re-run it after any change: it re-exports first. If a server from an earlier
# run is still up on the port, it reuses that one (just refresh the page).
# Ctrl+C stops the server this script started.
param(
    [int]$Port = 8060,
    [switch]$NoBrowser
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

# 1. Export. `godot` is the profile function (newest winget build) or godot.cmd on PATH.
if (-not (Get-Command godot -ErrorAction SilentlyContinue)) {
    Write-Host 'godot command not found. Open a new PowerShell window (loads the profile) and retry.' -ForegroundColor Red
    exit 1
}
New-Item -ItemType Directory -Force -Path (Join-Path $root 'build\web') | Out-Null
Write-Host 'Exporting Web build...' -ForegroundColor Cyan
# Godot writes progress to stderr; in Windows PowerShell that would trip 'Stop', so relax it here.
$ErrorActionPreference = 'Continue'
$log = godot --headless --path $root --export-release 'Web' 'build/web/index.html' 2>&1 | ForEach-Object { "$_" }
$exportCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
$log | Where-Object { $_ -match 'ERROR' } | ForEach-Object { Write-Host $_ -ForegroundColor Red }
if ($exportCode -ne 0) {
    Write-Host "Export failed (exit $exportCode). Run the export command alone to see the full log." -ForegroundColor Red
    exit 1
}

# 2. Serve (or reuse a server already on the port), then 3. open the browser.
$url = "http://localhost:$Port/"
$listening = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($listening) {
    Write-Host "A server is already running on port $Port - reusing it." -ForegroundColor Yellow
    if (-not $NoBrowser) { Start-Process $url }
    Write-Host "Refresh $url to load the new build."
    exit 0
}

$server = Start-Process -FilePath 'python' -ArgumentList @("`"$root\tools\serve_web.py`"", $Port) -NoNewWindow -PassThru
Start-Sleep -Milliseconds 800
if ($server.HasExited) {
    Write-Host 'The web server failed to start (is Python installed?).' -ForegroundColor Red
    exit 1
}
if (-not $NoBrowser) { Start-Process $url }
Write-Host "Playing at $url  -  click the game once for keyboard focus. Ctrl+C stops the server." -ForegroundColor Green
try {
    Wait-Process -Id $server.Id
} finally {
    if (-not $server.HasExited) { Stop-Process -Id $server.Id -Force }
}
